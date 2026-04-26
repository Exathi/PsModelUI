function New-ViewModelMethod {
    <#
        .SYNOPSIS
        Creates a pscustomobject to be consumed by New-ViewModel to create a class method.

        .PARAMETER Name
        Name of the method to be defined in the class by New-ViewModel.

        .PARAMETER Body
        Body of the method to be defined in the class by New-ViewModel.
        Uses the paramblock to define parameters that the method will receive.
        **Paramblock is not required if the method doesn't need parameters.

        All $this references will be of the class.

        .PARAMETER CommandName
        If specified, a command with this name will be created as that invokes the method.

        .PARAMETER ExcludeCommand
        If $true, no command will be created for this method. CommandName will be ignored if ExcludeCommand is $true.

        .PARAMETER Throttle
        The max number of times the equivalent method command can be running at a given time.

        .PARAMETER IsAsync
        This signals the equivalent command to be invoked in another runspace if $true or on the console thread.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter(Mandatory)]
        [scriptblock]$Body,
        [string]$CommandName,
        [switch]$ExcludeCommand,
        [int]$Throttle = 1,
        [bool]$IsAsync = $true
    )

    [pscustomobject]@{
        Name = $Name
        Body = $Body.Ast.GetScriptBlock()
        CommandName = $CommandName
        ExcludeCommand = $ExcludeCommand
        Throttle = $Throttle
        IsAsync = $IsAsync
    }
}
