function New-Class {
    <#
        .SYNOPSIS
        Dynamically creates a class object that inherits ViewModeBase.
        Properties preceeed by `$this` used in Methods that aren't defined in PropertyDeclaration will automatically be defined as a property of the class.
        Method overloads are not supported.

        Allows for classes of the same type name with different properties and methods but allows for hot reloading of classes.

        .EXAMPLE
        $A = New-Class -ClassName 'ClassType' -PropertyDeclaration 'One'
        $B = New-Class -ClassName 'ClassType' -PropertyInit ([pscustomobject]@{
            Name = 'NewProperty'
            Type = ([string])
            Init = 'Hello World'
        })
        $C = New-Class -ClassName 'ClassType' -Methods ([pscustomobject]@{
            Name = 'ClassMethod'
	        Body = {return 'Hello World'}
        })

        .PARAMETER ClassName
        The name of the class
        'MyClass'

        Creates:
        class MyClass : ViewModeBase {
            MyClass() {}
        }

        .PARAMETER Inherits
        The name of the class to inherit and interface names.
        Follows powershell interitance so only ONE class can be inherited and any dotnet interfaces can be added.

        'Foo', 'System.IDisposable', System.ComponentModel.INotifyPropertyChanged

        class Foo {
            $Property = 1
        }

        class Bar : Foo, System.IDisposable, System.ComponentModel.INotifyPropertyChanged {
            $NewProperty = 2
            Dispose(){}
            $PropertyChanged
            add_PropertyChanged([System.ComponentModel.PropertyChangedEventHandler]$handler) {}
            remove_PropertyChanged([System.ComponentModel.PropertyChangedEventHandler]$handler) {}
        }

        .PARAMETER PropertyDeclaration
        Takes an array of strings.
        @('property1', 'PropertY2')

        Creates:

        class ViewModel : ViewModelBase {
            $property1
            $PropertY2
        }

        .PARAMETER Methods
        Will also create class properties for methods that call $this.propertyname that isn't in $PropertyDeclaration
        Requires a hashtable of name and it's Body as a scriptblock
        @(
            DoMethod = {return 'hello world'}
            OtherMethod = {$this.Property = 'foo'} # if '$Property' is not defined in PropertyDeclaration, it will be added automatically.
        )

        Creates:

        class ViewModel : ViewModelBase {
            $Property
            [object]DoMethod() {
                return "hello world"
            }
            [void]OtherMethod() {
                $this.Property = 'foo'
            }
        }

        .PARAMETER Unbound
        Creates the class with no runspace affinity if $true. Otherwise class methods cannot be called when the UI is running.

        .PARAMETER AsString
        Returns the full class definition as a string instead of the object.
    #>
    [CmdletBinding(DefaultParameterSetName = 'AsObject')]
    param (
        [Parameter(Mandatory)]
        [string]$ClassName,
        [string[]]$Inherits = 'pscustomobject',
        [Parameter(ParameterSetName = 'AsObject')]
        [string[]]$PropertyDeclaration,
        [Parameter(ParameterSetName = 'AsTypeWithDefinition')]
        [pscustomobject[]]$PropertyInit,
        [pscustomobject[]]$Methods,
        [bool]$Unbound = $true,
        [bool]$AutomaticProperties = $false,
        [switch]$AsString
    )

    $StringBuilder = [System.Text.StringBuilder]::new()

    # start class line
    $null = $StringBuilder.Append("class $ClassName")
    if ($Inherits) {
        $null = $StringBuilder.Append(' : ')
        $null = $StringBuilder.Append(($Inherits -join ','))
    }
    $null = $StringBuilder.AppendLine(' {')

    # class properties
    foreach ($Name in $PropertyDeclaration) {
        if ($Name -notmatch '^\w+$') { throw 'property name can only contain letters and numbers' }
        $null = $StringBuilder.AppendLine(('$_{0}' -f $Name))
    }

    foreach ($ClassProperty in $PropertyInit) {
        if ($ClassProperty.Name -notmatch '^\w+$') { throw 'property name can only contain letters and numbers' }
        if ($ClassProperty.ExcludePrefix) {
            $null = $StringBuilder.AppendLine(('[{0}]${1}' -f $ClassProperty.Type, $ClassProperty.Name))
        } else {
            $null = $StringBuilder.AppendLine(('[{0}]$_{1}' -f $ClassProperty.Type, $ClassProperty.Name))
        }
    }

    # base constructor
    $null = $StringBuilder.AppendLine(('{0}(){{' -f $ClassName))

    foreach ($ClassProperty in $PropertyInit) {
        if ($null -eq $ClassProperty.Init -or $ClassProperty.Init.Ast.EndBlock.Statements.Count -eq 0) { continue }

        if ($ClassProperty.ExcludePrefix) {
            $BackingFieldName = "psobject.$($ClassProperty.Name)"
        } else {
            $BackingFieldName = "psobject._$($ClassProperty.Name)"
        }

        $RawText = @"
`$this.$BackingFieldName = [scriptblock]::Create(
@'
,($($ClassProperty.Init.ToString()))
'@
).InvokeReturnAsIs()
"@
        $null = $StringBuilder.AppendLine($RawText)
    }

    $null = $StringBuilder.AppendLine(('}}' -f $ClassName))


    # methods
    foreach ($PSMethod in $Methods) {
        if (($PSMethod.Body.Ast.EndBlock.Statements.Where({ $null -ne $_.Pipeline })).Count -eq 0) {
            $null = $StringBuilder.Append(('[void]{0}(' -f $PSMethod.Name))
        } else {
            $null = $StringBuilder.Append(('[object]{0}(' -f $PSMethod.Name))
        }
        $ParameterText = if ($PSMethod.Body.Ast.ParamBlock.Parameters.Extent.Text) {
            $PSMethod.Body.Ast.ParamBlock.Parameters.Extent.Text -join ', '
        } else {
            ''
        }
        $null = $StringBuilder.AppendLine(('{0}) {{' -f $ParameterText))

        foreach ($Statement in $PSMethod.Body.Ast.EndBlock.Statements.Extent.Text) {
            $null = $StringBuilder.AppendLine($Statement)
        }
        $null = $StringBuilder.AppendLine('}')
    }

    # end class definition
    $null = $StringBuilder.AppendLine('}')

    # find all $this references from preliminary definition and create class properties for them.
    $UniqueProperties = [System.Collections.Generic.HashSet[string]]::new()
    if ($AutomaticProperties) {
        $PreliminaryDefinition = ([scriptblock]::Create($StringBuilder.ToString()))
        $ClassProperties = $PreliminaryDefinition.Ast.FindAll({ $args[0] -is [System.Management.Automation.Language.VariableExpressionAst] }, $true) | Where-Object { $_.VariablePath.UserPath -eq 'this' }

        # remove the newline and closing brace to add $this variables as properties from methods.
        $null = $StringBuilder.Remove($StringBuilder.Length - 3, 3)

        # get all unique $this properties and add them as $property if not added in $PropertyDeclaration
        foreach ($ClassProperty in $ClassProperties.Parent.Member.Extent.Text) {
            if ([string]::IsNullOrWhiteSpace($ClassProperty)) { continue }
            if ($PropertyDeclaration -contains $ClassProperty) { continue }
            if ($PropertyInit.Name -contains $ClassProperty) { continue }
            $null = $UniqueProperties.Add($ClassProperty)
        }

        foreach ($ClassProperty in $UniqueProperties.GetEnumerator()) {
            $null = $StringBuilder.AppendLine('$_{0}' -f $ClassProperty)
        }

        # end class definition
        $null = $StringBuilder.AppendLine('}')
    }

    if ($AsString) {
        return $StringBuilder.ToString()
    }

    $Definition = ([scriptblock]::Create($StringBuilder.ToString()))
    . $Definition

    $DynamicClass = if ($Unbound) {
        New-UnboundClassInstance $ClassName
    } else {
        [activator]::CreateInstance($ClassName)
    }

    foreach ($ClassProperty in $PropertyDeclaration) {
        $ProperName = if ($ClassProperty.StartsWith('_')) { $ClassProperty.Remove(0, 1) } else { $ClassProperty }
        $Splat = @{
            Name = $ProperName
            MemberType = 'ScriptProperty'
            Value = [scriptblock]::Create('return ,$this.psobject.{0}' -f $ClassProperty)
            SecondValue = [scriptblock]::Create(('param($value)
                $this.psobject.{0} = $value
                $this.psobject.RaisePropertyChanged("{1}")' -f $ClassProperty, $ProperName)
            )
        }
        $DynamicClass | Add-Member @Splat
    }

    foreach ($ClassProperty in $PropertyInit) {
        if ($ClassProperty.Get -and $ClassProperty.Set) {
            $DynamicClass | Add-Member -MemberType ScriptProperty -Name $ClassProperty.Name -Value $ClassProperty.Get.Ast.GetScriptBlock() -SecondValue $ClassProperty.Set.Ast.GetScriptBlock() -Force
        } else {
            if ($ClassProperty.ExcludePrefix) {
                $BackingFieldName = $ClassProperty.Name
            } else {
                $BackingFieldName = "_$($ClassProperty.Name)"
            }
            $Splat = @{
                Name = $ClassProperty.Name
                MemberType = 'ScriptProperty'
                Value = [scriptblock]::Create('return ,$this.psobject.{0}' -f $BackingFieldName)
                SecondValue = [scriptblock]::Create(('param($value)
                        $this.psobject.{0} = $value' -f $BackingFieldName)
                )
            }
            $DynamicClass | Add-Member @Splat
        }
    }

    foreach ($ClassProperty in $UniqueProperties.GetEnumerator()) {
        $ProperName = "_$ClassProperty"
        $Splat = @{
            Name = $ClassProperty
            MemberType = 'ScriptProperty'
            Value = [scriptblock]::Create('return ,$this.psobject.{0}' -f $ProperName)
            SecondValue = [scriptblock]::Create(('param($value)
                        $this.psobject.{0} = $value' -f $ProperName)
            )
        }
        $DynamicClass | Add-Member @Splat
    }

    $DynamicClass
}
