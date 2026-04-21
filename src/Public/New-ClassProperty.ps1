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

        .PARAMETER Initialization
        A scriptblock containing the initial value or object to create.
        Similar to list initialization in C++. Same braces!

        { 123 }
        { [System.Collections.Generic.List[object]]::new() }

        .EXAMPLE
        New-ViewModelProperty -PropertyName 'a' -Type int -Initialization {1+1}
        The above will be consumed in New-ViewModel to generate:

        class Sample {
            [int]$a
            Sample() {
                $this.a = {1+1}.InvokeReturnAsIs()
            }
        }
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Name,
        [type]$Type,
        [scriptblock]$Initialization
    )

    [pscustomobject]@{
        Name = $Name
        Type = if ($Type) { $Type } else { [object] }
        Initialization = if ($Initialization) { $Initialization } else { [scriptblock]::create() }
    }
}
