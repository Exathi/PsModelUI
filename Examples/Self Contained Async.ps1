Add-Type -AssemblyName PresentationFramework, WindowsBase -ErrorAction Stop
[NoRunspaceAffinity()]
class ViewModelBase : PSCustomObject, System.ComponentModel.INotifyPropertyChanged {
    # INotifyPropertyChanged Implementation
    [ComponentModel.PropertyChangedEventHandler]$PropertyChanged
    add_PropertyChanged([System.ComponentModel.PropertyChangedEventHandler]$handler) {
        $this.psobject.PropertyChanged = [Delegate]::Combine($this.psobject.PropertyChanged, $handler)
    }
    remove_PropertyChanged([System.ComponentModel.PropertyChangedEventHandler]$handler) {
        $this.psobject.PropertyChanged = [Delegate]::Remove($this.psobject.PropertyChanged, $handler)
    }
    RaisePropertyChanged([string]$propname) {
        if ($this.psobject.PropertyChanged) {
            $evargs = [System.ComponentModel.PropertyChangedEventArgs]::new($propname)
            $this.psobject.PropertyChanged.Invoke($this, $evargs)
        }
    }
    # End INotifyPropertyChanged Implementation
    ViewModelBase() {}
    [void]StartAsync($ClassMethod) {
        $Powershell = [powershell]::Create()
        $ScriptBlock = {
            param($Delegate)
            $Delegate.Invoke()
        }.Ast.GetScriptBlock()
        $null = $Powershell.AddScript($ScriptBlock)
        $null = $Powershell.AddParameter('Delegate', $ClassMethod)
        $Handle = $Powershell.BeginInvoke()
    }
}

class ActionCommand : ViewModelBase, System.Windows.Input.ICommand {
    # ICommand Implementation
    [System.EventHandler]$InternalCanExecuteChanged
    add_CanExecuteChanged([EventHandler] $value) {
        $this.psobject.InternalCanExecuteChanged = [Delegate]::Combine($this.psobject.InternalCanExecuteChanged, $value)
    }
    remove_CanExecuteChanged([EventHandler] $value) {
        $this.psobject.InternalCanExecuteChanged = [Delegate]::Remove($this.psobject.InternalCanExecuteChanged, $value)
    }
    [bool]CanExecute([object]$CommandParameter) {
        return $true
    }
    [void]Execute([object]$CommandParameter) {
        if ($this.psobject.IsAsync) {
            $null = $this.psobject.StartAsync($this.psobject.Action)
        } else {
            $this.psobject.Action.Invoke()
        }
    }
    # End ICommand Implementation
    ActionCommand([System.Management.Automation.PSMethod]$Action, $IsAsync) {
        $this.psobject.Action = $Action
        $this.psobject.IsAsync = $IsAsync
    }
    $Action
    $IsAsync
}

$xaml = [xml]::new()
$xaml.LoadXml(@'
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    Title="PsModelUI 7.5" ThemeMode="Dark" WindowStartupLocation="CenterScreen" Width="640" Height="480">
	<StackPanel HorizontalAlignment="Center" VerticalAlignment="Center">
		 <TextBlock Text="{Binding CustomerNameValue, Mode=TwoWay, UpdateSourceTrigger=PropertyChanged}" />
		 <Button Content="Async" Command="{Binding AsyncCustomerNameCommand}" />
		 <Button Content="Freeze" Command="{Binding CustomerNameCommand}" />
	</StackPanel>
</Window>
'@)
class ViewModel : ViewModelBase {
    $AsyncCustomerNameCommand
    $CustomerNameCommand
    $_CustomerNameValue = 'Hello World'
    ViewModel() {
        $Splat = @{
            Name = 'CustomerNameValue'
            MemberType = 'ScriptProperty'
            Value = [scriptblock]::Create('return ,$this.psobject.{0}' -f '_CustomerNameValue')
            SecondValue = [scriptblock]::Create('param($value)
				$this.psobject.{0} = $value
				$this.psobject.RaisePropertyChanged("CustomerNameValue")' -f '_CustomerNameValue'
            )
        }
        $this | Add-Member @Splat
    }
    [void]CustomerName() {
        Start-Sleep -Seconds 2
        $this.CustomerNameValue = Get-Random
    }
}
$ViewModel = [ViewModel]::new()
$ViewModel.psobject.AsyncCustomerNameCommand = [ActionCommand]::new($ViewModel.psobject.CustomerName, $true)
$ViewModel.psobject.CustomerNameCommand = [ActionCommand]::new($ViewModel.psobject.CustomerName, $false)
$Window = [System.Windows.Markup.XamlReader]::Load(([System.Xml.XmlNodeReader]::new($xaml)))
$Window.DataContext = $ViewModel
$Window.ShowDialog()
