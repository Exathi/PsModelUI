function New-ClassProperty {
    <#
        .SYNOPSIS
        Creates a pscustomobject to be consumed by New-ViewModel to create a class property with initial value.

        .PARAMETER PropertyName
        Name of the property

        .PARAMETER Type
        Type of the property
        'string'
        ([string])
        'object'
        'int'
        ([System.Collections.Generic.List[object]])

        .PARAMETER Init
        A scriptblock containing the initial value or object to create.
        Similar to list initialization in C++. Same braces!

        { 123 }
        { [System.Collections.Generic.List[object]]::new() }

        .PARAMETER ExcludePrefix
        Excludes adding an underscore "_" to the backing class property.
        Used for properties that need the actual object to bind since Add-Member value/secondvalue only return an object and not a guaranteed type.
        If the ScriptProperty is the same name as the backing field, the binding will use the backing field and may ignore the setter of ScriptProperty.

        **Bind as usual and a converter or bind to the _underlying object. Should only be needed for ILists/IEnumberable.

        .PARAMETER Get
        A scriptblock that overwrites the default Get of the property. The scriptblock must return the value to be retrieved.

        .PARAMETER Set
        A scriptblock that overwrites the default the Set of the property. The scriptblock must have a parameter to receive the value being set.
        If used with New-ViewModel, you will need to include $this.psobject.RaisePropertyChanged("PropertyName/_PropertyName") in the scriptblock to update bindings.

        .EXAMPLE
        New-ViewModelProperty -PropertyName 'a' -Type int -Init {1+1}
        The above will be consumed in New-ViewModel to generate:

        class Sample {
            [int]$_a
            Sample() {
                $this.a = [scriptblock]::Create(
@'
                ,(1+1)
'@
                ).InvokeReturnAsIs()
            }
        }
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Name,
        [type]$Type,
        [scriptblock]$Init,
        [Parameter(ParameterSetName = 'WithAccessors')]
        [scriptblock]$Get,
        [Parameter(ParameterSetName = 'WithAccessors')]
        [scriptblock]$Set,
        [switch]$ExcludePrefix
    )

    if ($Name -notmatch '^\w+$') { throw 'Name can only contain letters and numbers' }

    [pscustomobject]@{
        Name = $Name
        Type = if ($Type) { $Type } else { [object] }
        Init = if ($Init.Ast.EndBlock.Statements.Count -gt 0) { $Init } else { $null }
        ExcludePrefix = $ExcludePrefix
        Get = if ($Get.Ast.EndBlock.Statements.Count -gt 0) { $Get } else { $null }
        Set = if ($Set.Ast.EndBlock.Statements.Count -gt 0) { $Set } else { $null }
    }
}
