Import-Module .\PsModelUI

function Invoke-SampleFunction {
    [CmdletBinding()]
    param (
        [int]$Max = [int]::MaxValue
    )
    Start-Sleep -Seconds 2
    Get-Random -Maximum $Max
}

$LongTask = New-ViewModelMethod -MethodName 'LongTask' -MethodBody {
    $Random = Get-Random -Min 100 -Max 5000
    Start-Sleep -Milliseconds $Random
    $this.LongTaskView = $Random
}

$AnotherTask = New-ViewModelMethod -MethodName 'AnotherTask' -MethodBody {
    $DataRow = [pscustomobject]@{
        Id = [runspace]::DefaultRunspace.Id
        Type = 'Start'
        Time = Get-Date
        Snapshot = $this.LongTaskView
        Method = 'AnotherTask'
    }

    $this.DataGridJobs.Add($DataRow)

    $DummyItems = 1..10
    $DummyItems | ForEach-Object {
        $DataRow = [pscustomobject]@{
            Id = [runspace]::DefaultRunspace.Id
            Type = 'Processing'
            Time = Get-Date
            Snapshot = $this.LongTaskView
            Method = 'AnotherTask'
        }

        $this.DataGridJobs.Add($DataRow)

        $Random = Get-Random -Min 1 -Max 3000
        Start-Sleep -Milliseconds $Random
    }

    $DataRow = [pscustomobject]@{
        Id = [runspace]::DefaultRunspace.Id
        Type = 'End'
        Time = Get-Date
        Snapshot = $this.LongTaskView
        Method = 'AnotherTask'
    }
    $this.DataGridJobs.Add($DataRow)
}

$SampleFunction = New-ViewModelMethod -MethodName 'SampleFunction' -MethodBody {
    $this.SampleFunctionView = Invoke-SampleFunction
}

$DotSourced = New-ViewModelMethod -MethodName 'DotSourced' -MethodBody {
    try {
        $this.DotSourcedView = . .\DemoDotSource.ps1
    } catch {
        Write-Warning "Method DotSourced failed. Current location is: '$PWD' and the dotsourced script isn't here. Try to source the fullpath, or '[Environment]::CurrentDirectory = Get-Location'."
    }
} -Throttle 1

$ProgressBar = New-ViewModelMethod -MethodName 'ProgressBar' -MethodBody {
    $Start = 1
    $End = 1000000
    $Start..$End | ForEach-Object {
        $Progress = ($_ / $End * 100)
        if ($Progress % 1 -eq 0) { $this.StatusPercent = $Progress }

        while ($this.IsPaused) {
            Start-Sleep -Milliseconds 50
        }
    }
} -Throttle 1

$ProgressPause = New-ViewModelMethod -MethodName 'ProgressPause' -MethodBody {
    $this.IsPaused = !$this.IsPaused
    $this.Status = if ($this.IsPaused) { 'Resume' } else { 'Pause' }
} -IsAsync $false

Set-ViewModelPool -Functions @(
    'Invoke-SampleFunction'
)

$Splat = @{
    ClassName = 'MainViewModel'
    PropertyNames = @(
        'DataGridJobsLock'
    )
    Methods = @(
        $LongTask
        $AnotherTask
        $SampleFunction
        $DotSourced
        $ProgressBar
        $ProgressPause
    )
    Unbound = $true
    CreateMethodCommand = $true
}

# $Splat.AsString = $true
# $MainViewModelDefinition = New-ViewModel @Splat
# $MainViewModelDefinition

$MainViewModel = New-ViewModel @Splat

# Populate ViewModel.
$MainViewModel.Status = 'Pause'
$MainViewModel.DataGridJobsLock = [object]::new()
$MainViewModel.DataGridJobs = [System.Collections.ObjectModel.ObservableCollection[Object]]::new()
[System.Windows.Data.BindingOperations]::EnableCollectionSynchronization($MainViewModel.DataGridJobs, $MainViewModel.DataGridJobsLock)

# Load window
$View = if ($PSVersionTable.PSVersion.Major -eq 5) {
    "$PSScriptRoot\DemoXaml\MainWindowWindowsPowershell.xaml"
} else {
    "$PSScriptRoot\DemoXaml\MainWindowPwsh.xaml"
}

$Window = New-WpfObject -Path $View -DataContext $MainViewModel

$ResourceDictionary = New-WpfObject -Path "$PSScriptRoot\DemoXaml\LightTheme.xaml"
$Window.Resources.MergedDictionaries.Add($ResourceDictionary)
$ResourceDictionary = New-WpfObject -Path "$PSScriptRoot\DemoXaml\Common.xaml"
$Window.Resources.MergedDictionaries.Add($ResourceDictionary)

$Window.ShowDialog()
