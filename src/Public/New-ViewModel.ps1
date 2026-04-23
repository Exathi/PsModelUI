function New-ViewModel {
    <#
        .SYNOPSIS
        Dynamically creates a class object that inherits ViewModeBase.
        Properties preceeed by `$this` used in Methods that aren't defined in PropertyDeclaration will automatically be defined as a property of the class.
        Method overloads are not supported.

        Allows for classes of the same type name with different properties and methods but allows for hot reloading of classes.

        .EXAMPLE
        $A = New-ViewModel -ClassName 'ClassType' -PropertyDeclaration 'One'
        $B = New-ViewModel -ClassName 'ClassType' -PropertyInitialization ([pscustomobject]@{
            Name = 'NewProperty'
            Type = ([string])
            Initialization = 'Hello World'
        })
        $C = New-ViewModel -ClassName 'ClassType' -Methods ([pscustomobject]@{
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

        .PARAMETER CreateMethodCommand
        Creates a Command object for each method in $Methods that is populated with an [ActionCommand]
        Overloads are not supported.

        class ViewModel : ViewModelBase {
            $DoMethodCommand
            [object]DoMethod() {
                return "hello world"
            }
        }

        .PARAMETER AsString
        Returns the full class definition as a string instead of the object.
    #>
    [CmdletBinding(DefaultParameterSetName = 'AsObject')]
    param (
        [Parameter(Mandatory)]
        [string]$ClassName,
        [Parameter(ParameterSetName = 'AsObject')]
        [string[]]$PropertyDeclaration,
        [Parameter(ParameterSetName = 'AsTypeWithDefinition')]
        [pscustomobject[]]$PropertyInitialization,
        [pscustomobject[]]$Methods,
        [bool]$Unbound = $true,
        [bool]$CreateMethodCommand = $true,
        [switch]$AsString
    )

    $StringBuilder = [System.Text.StringBuilder]::new()

    # start class line
    $null = $StringBuilder.Append("class $ClassName")
    $null = $StringBuilder.Append(' : ViewModelBase')
    $null = $StringBuilder.AppendLine(' {')

    # class properties
    foreach ($Name in $PropertyDeclaration) {
        if ($Name -notmatch '^\w+$') { throw 'property name can only contain letters and numbers' }
        $null = $StringBuilder.AppendLine(('${0}' -f $Name))
    }

    foreach ($ClassProperty in $PropertyInitialization) {
        if ($ClassProperty.Name -notmatch '^\w+$') { throw 'property name can only contain letters and numbers' }
        $null = $StringBuilder.AppendLine(('[{0}]${1}' -f $ClassProperty.Type, $ClassProperty.Name))
    }

    # base constructor
    $null = $StringBuilder.AppendLine(('{0}(){{' -f $ClassName))

    foreach ($ClassProperty in $PropertyInitialization) {
        if ($null -eq $ClassProperty.Initialization -or $ClassProperty.Initialization.Ast.EndBlock.Statements.Count -eq 0) { continue }
        $RawText = @"
`$this.$($ClassProperty.Name) = [scriptblock]::Create(
@'
,($($ClassProperty.Initialization.ToString()))
'@
).InvokeReturnAsIs()
"@
        $null = $StringBuilder.AppendLine($RawText)
    }

    $null = $StringBuilder.AppendLine(('}}' -f $ClassName))


    # methods
    foreach ($PSMethod in $Methods) {
        # Create a command property for the method and append 'Command' to the end.
        if ($CreateMethodCommand) {
            if ([string]::IsNullOrWhiteSpace($PSMethod.CommandName)) {
                $null = $StringBuilder.AppendLine(('${0}Command' -f $PSMethod.Name))
            } else {
                $null = $StringBuilder.AppendLine(('${0}' -f $PSMethod.CommandName))
            }
        }

        if (($PSMethod.Body.Ast.EndBlock.Statements.Where({ $null -ne $_.Pipeline })).Count -eq 0) {
            $null = $StringBuilder.AppendLine(('[void]{0}({1}) {{' -f $PSMethod.Name, $PSMethod.MethodParameterNames))
        } else {
            $null = $StringBuilder.AppendLine(('[object]{0}({1}) {{' -f $PSMethod.Name, $PSMethod.MethodParameterNames))
        }
        $null = $StringBuilder.AppendLine($($PSMethod.Body.ToString().Trim()))
        $null = $StringBuilder.AppendLine('}')
    }

    # end class definition
    $null = $StringBuilder.AppendLine('}')

    # find all $this references from preliminary definition
    $DefinitionBeforeVariables = ([scriptblock]::Create($StringBuilder.ToString()))
    $ClassProperties = $DefinitionBeforeVariables.Ast.FindAll({ $args[0] -is [System.Management.Automation.Language.VariableExpressionAst] }, $true) | Where-Object { $_.VariablePath.UserPath -eq 'this' }

    # remove the newline and closing brace to add $this variables as properties from methods.
    $null = $StringBuilder.Remove($StringBuilder.Length - 3, 3)

    # get all unique $this properties and add them as $property if not added in $PropertyDeclaration
    $UniqueProperties = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($Property in $ClassProperties.Parent.Member.Extent.Text) {
        if ([string]::IsNullOrWhiteSpace($Property)) { continue }
        if ($PropertyDeclaration -contains $Property) { continue }
        if ($PropertyInitialization.Name -contains $Property) { continue }
        $null = $UniqueProperties.Add($Property)
    }

    foreach ($Property in $UniqueProperties.GetEnumerator()) {
        $null = $StringBuilder.AppendLine('${0}' -f $Property)
    }

    # finish class definition
    $null = $StringBuilder.AppendLine('}')

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

    # add a command property for each method
    if ($CreateMethodCommand) {
        foreach ($PSMethod in $Methods) {
            $CommandName = if ([string]::IsNullOrWhiteSpace($PSMethod.CommandName)) { "$($PSMethod.Name)Command" } else { $PSMethod.CommandName }
            $DynamicClass."$CommandName" = New-ActionCommand -MethodName $PSMethod.Name -Target $DynamicClass -Throttle $PSMethod.Throttle -IsAsync $PSMethod.IsAsync
        }
    }

    if (!$script:ViewModelThread['Pool'] -or $script:ViewModelThread['Pool'].IsDisposed) { Set-ViewModelPool }
    $DynamicClass.psobject.ViewModelThread = $script:ViewModelThread

    $DynamicClass
}
