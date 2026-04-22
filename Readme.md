# PsModelUI - Powershell with Wpf and Databinding
[![Static Badge](https://img.shields.io/badge/Powershell%20Gallery-1.1.0-blue)](https://www.powershellgallery.com/packages/PsModelUI/)

### Challenge
1. To write a GUI in Windows Powershell and Pwsh 7.5+
2. No custom written C# classes through `Add-Type`.
3. Limited to resources that come natively with Windows 11.

### Result
An **Asynchronous** PowerShell UI! Supported by a **ViewModel** and **Command Bindings**. Bonus updated theming with Pwsh 7.5+ that came with .NET 9.

Revisited and simplified for Pwsh. Previous version is in the archive for those that followed it and for some obscure findings.


<img width="1280" height="802" alt="Demo" src="https://github.com/user-attachments/assets/59c90980-47a0-400b-a943-08ee99dffede" />



## Check out the Demo
``` Powershell
. '.\Demo.ps1'
```


## Getting Started

``` Powershell
Import-Module .\PsModelUI

$MethodName = New-ViewModelMethod -Name 'MethodName' -Body {
    $Random = Get-Random -Min 1 -Max 3000
    Start-Sleep -Milliseconds $Random
    $this.BoundViewProperty = $Random
}

$Splat = @{
    ClassName = 'ViewModel'
    Methods = @(
        $MethodName
    )
}

$ViewModel = New-ViewModel @Splat

# Remove ThemeMode="Dark" for Windows Powershell.
$Xaml = @'
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    Title="PsModelUI" ThemeMode="Dark" WindowStartupLocation="CenterScreen" Width="640" Height="480">
	<StackPanel HorizontalAlignment="Center" VerticalAlignment="Center">
		 <TextBlock Text="{Binding BoundViewProperty}" />
		 <Button Content="Async" Command="{Binding MethodNameCommand}" />
	</StackPanel>
</Window>
'@
$Window = New-WpfObject -Xaml $Xaml -DataContext $ViewModel
$Window.ShowDialog()

```


## Features
### Dynamic Class
Building a class has never been more verbose! Ever wanted to build your own class through functions? No? Now you can, with all the cons and none of the pros.

Build parts of a class until you're ready to piece it together.

``` Powershell
$MethodSplat = @{
	Name = 'ClassMethod'
	Body = {return 'Hello World'}
}
$ClassMethod = New-ViewModelMethod @MethodSplat

$PropertySplat = @{
	Name = 'ClassProperty'
	Type = ([string])
	Initialization = {'I have default a value'}
}
$ClassProperty = New-ClassProperty @PropertySplat

$ClassSplat = @{
	ClassName = 'DynamicClass'
	PropertyInitialization = @(
		$ClassProperty
	)
	Methods = @(
		$ClassMethod
	)
	Unbound = $true
    CreateMethodCommand = $true
}
$DynamicClass = New-ViewModel @ClassSplat

$DynamicClass
ClassProperty          ClassMethodCommand
-------------          ------------------
I have default a value @{Workers=System.Management.Automation.PSScriptProperty}

$DynamicClass.psobject.ClassMethod()
Hello World

# Class definition as a string
$ClassSplat.AsString = $true
$DynamicClassDefinition = New-ViewModel @ClassSplat
$DynamicClassDefinition

class DynamicClass : ViewModelBase {
[System.String]$ClassProperty
DynamicClass(){
$this.ClassProperty = [scriptblock]::Create(",('I have default a value')").InvokeReturnAsIs()
}
$ClassMethodCommand
[object]ClassMethod() {
return 'Hello World'
}

```


### Automatic Class Property Declaration
`New-ViewModel` detects class properties used in class methods but not defined by `New-ClassProperty` and automatically includes it in the class as property of type object.

``` Powershell
$MethodSplat = @{
    Name = 'ClassMethod'
    Body = {$this.AutoClassProperty = 'Hello World'}
}
$ClassMethod = New-ViewModelMethod @MethodSplat

$ClassSplat = @{
    ClassName = 'DynamicClass'
    Methods = $ClassMethod
	CreateMethodCommand = $false
}
$DynamicClass = New-ViewModel @ClassSplat
$DynamicClass.psobject.ClassMethod()
$DynamicClass

AutoClassProperty
-----------------
Hello World
```


## Minimal Setup Example

If you want to create the ViewModel class yourself:

``` Powershell
# Pwsh7.5 - copy paste into the terminal and check it out.
# Make sure to load Add-Types, ViewModelBase and ActionCommand first
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
	<StackPanel HorizontalAlignment="Center">
		 <TextBlock Text="{Binding CustomerNameValue}" />
		 <Button Content="Async" Command="{Binding AsyncCustomerNameCommand}" />
		 <Button Content="Freeze" Command="{Binding CustomerNameCommand}" />
	</StackPanel>
</Window>
'@)
class ViewModel : ViewModelBase {
	$AsyncCustomerNameCommand
	$CustomerNameCommand
	$CustomerNameValue = 'Hello World'
	ViewModel() {
		$Splat = @{
			Name = 'CustomerNameValue'
			MemberType = 'ScriptProperty'
			Value = [scriptblock]::Create('return ,$this.psobject.{0}' -f 'CustomerNameValue')
			SecondValue = [scriptblock]::Create('param($value)
				$this.psobject.{0} = $value
				$this.psobject.RaisePropertyChanged("{0}")' -f 'CustomerNameValue'
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

```


## How it works
### Inherit a pscustomobject
Since classes inherit `PSCustomObject`, properties are accessed `$Class.psobject.Property`. It functions as a accessible hidden (but not private or protected) property that will show intellisense after `.psobject`.

While the xaml can bind to `$Class.psobject.Property`, there won't be a way to call PropertyChanged in property setter. The xaml can find and bind to `Add-Member -MemberType ScriptProperty`. Since we inherited `PSCustomObject`, `$Class.Property` no longer exists, therefore we can add property definitions with the same name as the internal property with Getters and Setters for use in the Xaml with `Add-Member`!

``` Powershell
[NoRunspaceAffinity()]
class DemoClass : pscustomobject {
	$Prop = 'Foo'
	Method() {$this.Prop = 'bar'}
}
$DemoClass = [DemoClass]::new()
$DemoClass.Prop # nothing
$DemoClass.psobject.Prop # returns Foo
```

### Add script properties to a class
Now when the property is set with `$Class.Property = $Value`, it can properly call PropertyChanged on the backing property! You can use `$Class.Property` for notifying or access the backing field directly by `$Class.psobject.Property` similar to csharp `$Class.property` and internal `$Class._property`.

Methods will have to be called with `$Class.psobject.ClassMethod()`. This isn't a problem for the ui as buttons are bound to commands that invoke the method. I have not explored adding via `Add-Member -MemberType ScriptMethod`.

Because we execute class methods in a runspace, the class has to be unbound with `NoRunspaceAffinity` or `New-UnboundClassInstance`. For windows powershell compatibility, `New-UnboundClassInstance` is used internally to create the viewmodels. Being unbound allows class methods to be invoked accross runspaces.

``` Powershell
$DemoClass | Add-Member -Name 'Prop' -MemberType ScriptProperty -Value ([scriptblock]::Create('return ,$this.psobject.Prop')) -SecondValue ([scriptblock]::Create('param($value)
	$this.psobject.Prop = $value
	#$this.psobject.NotifyPropertyChanged("Prop")'))

$DemoClass.psobject.Method() # sets new value and calls property changed
$DemoClass.Prop # returns bar
```



## Pwsh and Powershell compatibility
* The main difference is the ViewModel setup.

* Pwsh has access to the attribute `[NoRunspaceAffinity()]`. Powershell 5.1 needs to create the class without a runspace.

``` Powershell
# Pwsh
$ViewModel = [MyViewModel]::new()
$ViewModel.psobject.WriteVerboseCommand = [ActionCommand]::new($ViewModel.psobject.WriteVerboseMethod, $true, $Target, 0)
$ViewModel.WriteVerboseMethod()
PS> VERBOSE: Prints to host

# Powershell
$ViewModel = New-UnboundClassInstance MyViewModel
$ViewModel.psobject.Dispatcher = [System.Windows.Threading.Dispatcher]::CurrentDispatcher
$ViewModel.psobject.WriteVerboseCommand = [ActionCommand]::new($ViewModel.psobject.WriteVerboseMethod, $true, $Target, 0)
$ViewModel.WriteVerboseMethod()
PS> VERBOSE: Prints to host
```

For times where you need to use the dispatcher:
``` Powershell
# Pwsh can implicitly convert methods to delegates so this is possible.
$Dispatcher.InvokeAsync($Class.Method)

# But has no room for a parameter.
$Dispatcher.InvokeAsync($Class.Method($Parameter))

# So we have to rely on BeginInvoke for method and its delegate with a parameter.
$Dispatcher.BeginInvoke(9, $Class.MethodDelegate, $Parameter)
```


## Updating the view from other runspaces

As long as methods do not update the same view property at the same time there is nothing to worry about.

`ActionCommand.Execute` invokes the provided PSMethod in another runspace. It will not run and block on the GUI thread because it is not bound to the runspace it was created in with attribute `[NoRunspaceAffinity()]` and Windows Powershell equivalent.

``` Powershell
# Update the view by setting property in class method.
# Provided that the property was setup with AddPropertyChangedToProperties() and bound in the xaml.
# Method works as is. Create an ActionCommand.IsAsync = $true to run in a runspace or false to run on the GUI thread.
[void]Method() {
	$NewValue = Invoke-RestMethod
	$this.Property = $NewValue.Result
}

# Use the internal method `$this.psobject.UpdateView` if somehow mutliple methods update the same class property at the same time.
# #Alternatively, use locks.
[void]Method() {
	$NewValue = Invoke-RestMethod
	$this.psobject.UpdateView([pscustomobject]@{
		Property = $NewValue.Result
	})
}
```


### Why not Start-ThreadJob
Start-ThreadJob alternative feels slower and you'll want something to clean up the jobs. Also does not come default in Windows Powershell.

``` Powershell
# The entirety of StartAsync() can be replaced with this but won't be able to run custom functions within the class method unless you pass an initialization script to define the function.
# And something else to clean up the job since Receive-Job with -AutoRemoveJob requires -Wait.

Start-ThreadJob -Scriptblock {
	param($MethodToRunAsync)
	$MethodToRunAsync.Invoke()
} -ArgumentList $MethodToRunAsync
```
