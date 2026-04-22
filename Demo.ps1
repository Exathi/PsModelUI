Import-Module .\PsModelUI

function Invoke-SampleFunction {
    [CmdletBinding()]
    param (
        [int]$Max = [int]::MaxValue
    )
    Start-Sleep -Seconds 2
    Get-Random -Maximum $Max
}

$LongTask = New-ViewModelMethod -Name 'LongTask' -Body {
    $Random = Get-Random -Min 100 -Max 5000
    Start-Sleep -Milliseconds $Random
    $this.LongTaskView = $Random
} -Throttle 0

$AnotherTask = New-ViewModelMethod -Name 'AnotherTask' -Body {
    $DataRow = [pscustomobject]@{
        Id = [runspace]::DefaultRunspace.Id
        Type = 'Start'
        Time = Get-Date
        Snapshot = $this.LongTaskView
        Method = 'AnotherTask'
    }

    $this.DataGridView.Add($DataRow)

    $DummyItems = 1..10
    $DummyItems | ForEach-Object {
        $DataRow = [pscustomobject]@{
            Id = [runspace]::DefaultRunspace.Id
            Type = 'Processing'
            Time = Get-Date
            Snapshot = $this.LongTaskView
            Method = 'AnotherTask'
        }

        $this.DataGridView.Add($DataRow)

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
    $this.DataGridView.Add($DataRow)
} -Throttle 2

$SampleFunction = New-ViewModelMethod -Name 'SampleFunction' -Body {
    $this.SampleFunctionView = Invoke-SampleFunction
}

$DotSourced = New-ViewModelMethod -Name 'DotSourced' -Body {
    try {
        $this.DotSourcedView = . .\DemoDotSource.ps1
    } catch {
        Write-Warning "Method DotSourced failed. Current location is: '$PWD' and the dotsourced script isn't here. Try to source the fullpath, or '[Environment]::CurrentDirectory = Get-Location'."
    }
}

$ProgressBar = New-ViewModelMethod -Name 'ProgressBar' -Body {
    $this.ProgressVisible = 'Visible'

    $Start = 1
    $End = 100
    $Start..$End | ForEach-Object {
        while ($this.IsPaused) {
            Start-Sleep -Milliseconds 100
        }

        $Progress = ($_ / $End * 100)
        if ($Progress % 1 -eq 0) { $this.StatusPercent = $Progress }
        Start-Sleep -Milliseconds 25
    }

    $this.ProgressVisible = 'Collapsed'
}

$ProgressPause = New-ViewModelMethod -Name 'ProgressPause' -Body {
    if ($this.ProgressVisible -eq 'Collapsed') { return }
    $this.IsPaused = !$this.IsPaused
    $this.Status = if ($this.IsPaused) { 'Resume' } else { 'Pause' }
} -IsAsync $false

Set-ViewModelPool -Functions @(
    'Invoke-SampleFunction'
)

$Splat = @{
    ClassName = 'MainViewModel'
    PropertyInitialization = @(
        New-ClassProperty -Name DataGridViewLock -Type ([object]) -Initialization { [object]::new() }
        New-ClassProperty -Name DataGridView -Type ([System.Collections.ObjectModel.ObservableCollection[Object]]) -Initialization { [System.Collections.ObjectModel.ObservableCollection[Object]]::new() }
        New-ClassProperty -Name Status -Type ([string]) -Initialization { 'Pause' }
        New-ClassProperty -Name ProgressVisible -Type ([string]) -Initialization { 'Collapsed' }
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
[System.Windows.Data.BindingOperations]::EnableCollectionSynchronization($MainViewModel.DataGridView, $MainViewModel.DataGridViewLock)

# Load window
$View = if ($PSVersionTable.PSVersion.Major -eq 5) {
    "$PSScriptRoot\DemoXaml\MainWindowWindowsPowershell.xaml"
} else {
    "$PSScriptRoot\DemoXaml\MainWindowPwsh.xaml"
}

$Window = New-WpfObject -Path $View -DataContext $MainViewModel
if ($PSVersionTable.PSVersion.Major -eq 5) {
    $ThemePath = "$PSScriptRoot\DemoXaml\LightTheme.xaml"
    $CommonPath = "$PSScriptRoot\DemoXaml\Common.xaml"
    $ResourceDictionary = New-WpfObject -Path $ThemePath
    $Window.Resources.MergedDictionaries.Add($ResourceDictionary)
    $ResourceDictionary = New-WpfObject -Path $CommonPath
    $Window.Resources.MergedDictionaries.Add($ResourceDictionary)
}
$Window.ShowDialog()

# Recreate object to be able to show again
# Retains information since it was all stored in $MainViewModel
# $Window = New-WpfObject -Path $View -DataContext $MainViewModel
# if ($PSVersionTable.PSVersion.Major -eq 5) {
#     $ResourceDictionary = New-WpfObject -Path $ThemePath
#     $Window.Resources.MergedDictionaries.Add($ResourceDictionary)
#     $ResourceDictionary = New-WpfObject -Path $CommonPath
#     $Window.Resources.MergedDictionaries.Add($ResourceDictionary)
# }
# $Window.ShowDialog()
