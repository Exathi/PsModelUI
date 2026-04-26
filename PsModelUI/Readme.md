# Functions

| Function | Description |
| - | - |
| New-ActionCommand | Creates an `[ActionCommand]` object when given a `psmethod` and its parent object. |
| New-Class | Creates a class object of the provided name. Can inherit one other class and multiple interfaces. |
| New-ClassMethod | Creates a `[pscustomobject]` with 2 properties: Name, and Body to be consumed by `New-Class`. |
| New-ClassProperty | Creates a `[pscustomobject]` with 3 properties: Name, Type, and Initialization to be consumed by `New-ViewModel` and `New-Class`. |
| New-ViewModel | Creates a new dynamic viewmodel class with properties from `New-ClassProperty`, and methods from `New-ViewModelMethod`. |
| New-ViewModelMethod | Creates a `[pscustomobject]` with 5 properties: Name, Body, CommandName, Throttle, and IsAsync to be consumed by `New-ViewModel`. |
| Set-ViewModelPool | Creates the runspacepool to be used by all classes created by `New-ViewModel`. Multiple calls will dispose of the old one and create a new. ViewModels hold a reference to a dictionary that holds the runspacepool so all viewmodels will always use the newest one when invoking commands async. |
| New-WpfObject | Creates a Wpf object with the provided xaml. |
