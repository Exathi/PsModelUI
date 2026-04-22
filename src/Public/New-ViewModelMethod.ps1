function New-ViewModelMethod {
    <#
        .SYNOPSIS
        Creates a pscustomobject to be consumed by New-ViewModel to create a class method.
        Overloads are not supported.

        .PARAMETER Name
        Name of the method to be defined in the class by New-ViewModel.

        .PARAMETER Body
        Body of the method to be defined in the class by New-ViewModel.
        All `$this` references will be of the class. Otherwise it is invalid if invoked as is.

        .PARAMETER MethodParameterNames
        Parameter names for the method.

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
        [string[]]$MethodParameterNames,
        [string]$CommandName,
        [int]$Throttle = 1,
        [bool]$IsAsync = $true
    )

    $Parameters = foreach ($Name in $MethodParameterNames) {
        if ($Name -notmatch '^\w+$') { throw ('parameter name can only contain letters and numbers: "{0}"' -f $Name) }
        '${0}' -f $Name
    }
    $JoinedParameters = $Parameters -join ','

    [pscustomobject]@{
        Name = $Name
        Body = $Body.Ast.GetScriptBlock()
        MethodParameterNames = $JoinedParameters
        CommandName = $CommandName
        Throttle = $Throttle
        IsAsync = $IsAsync
    }
}
