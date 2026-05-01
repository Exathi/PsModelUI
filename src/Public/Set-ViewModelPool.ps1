# Use an object so we can hot swap the runspacepool on calls to Set-ViewModelPool on all ViewModels if needed.
$script:ViewModelThread = [System.Collections.Concurrent.ConcurrentDictionary[string, System.Management.Automation.Runspaces.RunspacePool]]::new()

function Set-ViewModelPool {
    <#
        .SYNOPSIS
        Creates and opens the global runspacepool to be used by each viewmodel created by New-ViewModel.

        .DESCRIPTION
        Runspacepool is stored in module script scope: $script:ViewModelThread as a concurrent dictionary.
        It is added to each ViewModel created by New-ViewModel.
        Will be disposed and recreated on each call.

        .PARAMETER MaxRunspaces
        Max number of runspaces in the pool to be available for use.

        .PARAMETER Functions
        Name of the function defined inline to be available in the runspacepool.

        .PARAMETER StartupScripts
        Full paths of the scripts to run in the new runspace created by the runspacepool.
    #>
    [CmdletBinding()]
    param (
        [int]$MaxRunspaces = $([int]$env:NUMBER_OF_PROCESSORS + 1),
        [string[]]$Functions,
        [string[]]$StartupScripts
    )

    $State = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
    $State.ThrowOnRunspaceOpenError = $true

    foreach ($Name in $Functions) {
        $FunctionDefinition = Get-Content "Function:\$Name" -ErrorAction Stop
        $State.Commands.Add([System.Management.Automation.Runspaces.SessionStateFunctionEntry]::new($Name, $FunctionDefinition))
    }

    foreach ($ScriptPath in $StartupScripts) {
        $null = $State.StartupScripts.Add($ScriptPath)
    }

    if ($script:ViewModelThread['Pool']) {
        $script:ViewModelThread['Pool'].Dispose()
    }

    $script:ViewModelThread['Pool'] = [RunspaceFactory]::CreateRunspacePool(1, $MaxRunspaces, $State, (Get-Host))
    $script:ViewModelThread['Pool'].CleanupInterval = [timespan]::FromMinutes(5)
    $script:ViewModelThread['Pool'].Open()
}
