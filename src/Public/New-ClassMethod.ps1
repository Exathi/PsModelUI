function New-ClassMethod {
    <#
        .SYNOPSIS
        Creates a pscustomobject to be consumed by New-Class to create a class method.

        .PARAMETER Name
        Name of the method to be defined in the class by New-Class.

        .PARAMETER Body
        Body of the method to be defined in the class by New-Class.
        Uses the paramblock to define parameters that the method will receive.
        **Paramblock is not required if the method doesn't need parameters.

        All $this references will be of the class.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter(Mandatory)]
        [scriptblock]$Body
        # [bool]$IsAsync = $true
    )

    [pscustomobject]@{
        Name = $Name
        Body = $Body.Ast.GetScriptBlock()
        # IsAsync = $IsAsync
    }
}
