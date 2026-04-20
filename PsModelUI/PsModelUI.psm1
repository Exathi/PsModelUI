Add-Type -AssemblyName PresentationFramework, WindowsBase -ErrorAction Stop

$script:Powershell = $null

# Use an object so we can hot swap the runspacepool on calls to Set-ViewModelPool on all ViewModels if needed.
$script:ViewModelThread = [System.Collections.Concurrent.ConcurrentDictionary[string, System.Management.Automation.Runspaces.RunspacePool]]::new()

function New-UnboundClassInstance ([type] $type, [object[]] $arguments = $null, [scriptblock]$definition) {
    if ($null -eq $script:Powershell) {
        $script:Powershell = [powershell]::Create()
        $script:Powershell.AddScript({
                function New-UnboundClassInstance ([type] $type, [object[]] $arguments, [scriptblock]$definition) {
                    if ($definition) { $definition.Invoke() }
                    [activator]::CreateInstance($type, $arguments)
                }
            }.Ast.GetScriptBlock()
        ).Invoke()
        $script:Powershell.Commands.Clear()
    }

    try {
        if ($null -eq $arguments) { $arguments = @() }
        $result = $script:Powershell.AddCommand('New-UnboundClassInstance').
        AddParameter('type', $type).
        AddParameter('arguments', $arguments).
        AddParameter('definition', $definition).
        Invoke()
        return $result
    } finally {
        $script:Powershell.Commands.Clear()
    }
}

# [NoRunspaceAffinity()]
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

    ViewModelBase() {
        $this.psobject.UpdateWithDispatcherDelegate = $this.psobject.CreateDelegate($this.psobject.UpdateWithDispatcher)
        $this.psobject.AddPropertyChangedToProperties()
    }

    ViewModelBase([bool]$AddDefault) {
        $this.psobject.UpdateWithDispatcherDelegate = $this.psobject.CreateDelegate($this.psobject.UpdateWithDispatcher)
        if ($AddDefault) { $this.psobject.AddPropertyChangedToProperties() }
    }

    [void]AddPropertyChangedToProperties() {
        $this.psobject.AddPropertyChangedToProperties($null)
    }

    [void]AddPropertyChangedToProperties([string[]]$Exclude) {
        $PropertiesToExclude = 'PropertyChanged', 'Dispatcher', 'ViewModelThread', 'LastAction', 'UpdateWithDispatcherDelegate' + $Exclude
        $this.psobject.psobject.Members.Where({
                $_.MemberType -eq 'Property' -and
                $_.IsSettable -eq $true -and
                $_.IsGettable -eq $true -and
                $_.Name -notin $PropertiesToExclude
            }
        ).ForEach(
            {
                $Splat = @{
                    Name = $_.Name
                    MemberType = 'ScriptProperty'
                    Value = [scriptblock]::Create('return ,$this.psobject.{0}' -f $_.Name)
                    SecondValue = [scriptblock]::Create('param($value)
                        $this.psobject.{0} = $value
                        $this.psobject.RaisePropertyChanged("{0}")' -f $_.Name
                    )
                }
                $this | Add-Member @Splat
            }
        )
    }

    [Delegate]CreateDelegate([System.Management.Automation.PSMethod]$Method) {
        return $this.psobject.CreateDelegate($Method, $this)
    }

    [Delegate]CreateDelegate([System.Management.Automation.PSMethod]$Method, $Target) {
        $reflectionMethod = if ($Target.GetType().Name -eq 'PSCustomObject') {
            $Target.psobject.GetType().GetMethod($Method.Name)
        } else {
            $Target.GetType().GetMethod($Method.Name)
        }
        $parameterTypes = [System.Linq.Enumerable]::Select($reflectionMethod.GetParameters(), [func[object, object]] { $args[0].parametertype })
        $concatMethodTypes = $parameterTypes + $reflectionMethod.ReturnType
        $delegateType = [System.Linq.Expressions.Expression]::GetDelegateType($concatMethodTypes)
        $delegate = [delegate]::CreateDelegate($delegateType, $Target, $reflectionMethod.Name)
        return $delegate
    }

    [void]UpdateView([pscustomobject]$UpdateValue) {
        if ($null -eq $UpdateValue) { return }
        $this.psobject.InvokeDispatcher($UpdateValue)
    }

    hidden [void]UpdateWithDispatcher($UpdateValue) {
        $UpdateValue.psobject.Properties | ForEach-Object {
            try {
                $this.$($_.Name) = $_.Value
            } catch {
                Write-Warning ('Tried to update class property that does not exist: {0}' -f $_.Name)
            }
        }
    }

    hidden [void]InvokeDispatcher($UpdateValue) {
        $this.psobject.Dispatcher.BeginInvoke(9, $this.psobject.UpdateWithDispatcherDelegate, $UpdateValue)
    }

    [System.Threading.Tasks.Task]StartAsync($MethodToRunAsync, [ViewModelBase]$Target, $CommandParameter) {
        return $this.psobject.StartAsync($MethodToRunAsync, [ViewModelBase]$Target, $CommandParameter, $null)
    }

    [System.Threading.Tasks.Task]StartAsync($MethodToRunAsync, [ViewModelBase]$Target, $CommandParameter, $ActionCommand) {
        $Powershell = [powershell]::Create()
        $Powershell.RunspacePool = $Target.psobject.ViewModelThread['Pool'] # Will use a default runspace if ViewModelThread is $null

        $Delegate = if ($null -eq $CommandParameter -and $null -ne $ActionCommand) {
            {
                param($NoContextMethod, $ActionCommand)
                try {
                    $NoContextMethod.Invoke()
                    $null = $ActionCommand.psobject.Dispatcher.InvokeAsync($ActionCommand.psobject.RemoveWorkerDelegate)
                    # Pipeline output can be received in $LastAction.Result
                } catch { throw $_ }
            }
        } elseif ($null -eq $CommandParameter -and $null -eq $ActionCommand) {
            {
                param($NoContextMethod)
                try {
                    $NoContextMethod.Invoke()
                } catch { throw $_ }
            }
        } elseif ($null -ne $CommandParameter -and $null -eq $ActionCommand) {
            {
                param($NoContextMethod, $CommandParameter)
                try {
                    $NoContextMethod.Invoke($CommandParameter)
                } catch { throw $_ }
            }
        } else {
            {
                param($NoContextMethod, $ActionCommand, $CommandParameter)
                try {
                    $NoContextMethod.Invoke($CommandParameter)
                    $ActionCommand.psobject.Dispatcher.InvokeAsync($ActionCommand.psobject.RemoveWorkerDelegate)
                } catch { throw $_ }
            }
        }

        $NoContext = $Delegate.Ast.GetScriptBlock()

        $null = $Powershell.AddScript($NoContext)
        $null = $Powershell.AddParameter('NoContextMethod', $MethodToRunAsync)
        if ($null -ne $CommandParameter) { $null = $Powershell.AddParameter('CommandParameter', $CommandParameter) }
        if ($null -ne $ActionCommand) { $null = $Powershell.AddParameter('ActionCommand', $ActionCommand) }
        $Handle = $Powershell.BeginInvoke()

        $EndInvokeDelegate = $this.psobject.CreateDelegate($Powershell.EndInvoke, $Powershell) # Not needed with pwsh
        $Task = [System.Threading.Tasks.Task]::Factory.FromAsync($Handle, $EndInvokeDelegate)
        $this.psobject.LastAction = $Task

        return $Task
    }

    $Dispatcher #= [System.Windows.Threading.Dispatcher]::CurrentDispatcher # requires types to be loaded in ScriptsToProcess
    [System.Collections.Concurrent.ConcurrentDictionary[string, System.Management.Automation.Runspaces.RunspacePool]]$ViewModelThread
    [System.Threading.Tasks.Task]$LastAction
    $UpdateWithDispatcherDelegate
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
        if ($this.psobject.Throttle -gt 0) { return ($this.psobject.Workers -lt $this.psobject.Throttle) }
        if ($this.psobject.CanExecuteAction) { return $this.psobject.CanExecuteAction.Invoke() }
        return $true
    }

    [void]Execute([object]$CommandParameter) {
        if ($this.psobject.Throttle -gt 0) { $this.Workers++ }

        $Delegate = if ($this.psobject.Action) { $this.psobject.Action } else { $this.psobject.ActionObject }

        if ($this.psobject.IsAsync) {
            if ($this.psobject.Throttle -gt 0) {
                $null = $this.psobject.StartAsync($Delegate, $this.psobject.Target, $null, $this)
            } else {
                $null = $this.psobject.StartAsync($Delegate, $this.psobject.Target, $null)
            }
        } else {
            $Delegate.Invoke()
            if ($this.psobject.Throttle -gt 0) { $this.psobject.RemoveWorker() }
        }
    }
    # End ICommand Implementation

    ActionCommand([System.Management.Automation.PSMethod]$Action) : Base($false) {
        $this.psobject.Init($Action, $false, $null, 0)
    }

    ActionCommand([System.Management.Automation.PSMethod]$Action, [bool]$IsAsync, [ViewModelBase]$Target, [int]$Throttle) : Base($false) {
        $this.psobject.Init($Action, $IsAsync, $Target, $Throttle)
    }

    hidden Init([System.Management.Automation.PSMethod]$Action, [bool]$IsAsync, [ViewModelBase]$Target, [int]$Throttle) {
        $Delegate = $this.psobject.CreateDelegate($Action, $Target)

        $this.psobject.Action = $Delegate
        $this.psobject.IsAsync = $IsAsync
        $this.psobject.Target = $Target
        $this.psobject.Throttle = $Throttle

        $this.psobject.RaiseCanExecuteChangedDelegate = $this.psobject.CreateDelegate($this.psobject.RaiseCanExecuteChanged)
        $this.psobject.RemoveWorkerDelegate = $this.psobject.CreateDelegate($this.psobject.RemoveWorker)

        @('Workers').ForEach(
            {
                $Splat = @{
                    Name = $_
                    MemberType = 'ScriptProperty'
                    Value = [scriptblock]::Create('return ,$this.psobject.{0}' -f $_)
                    SecondValue = [scriptblock]::Create('param($value)
                        $this.psobject.{0} = $value
                        $this.psobject.RaisePropertyChanged("{0}")
                        if ($this.psobject.Dispatcher) {{
                            $this.psobject.RaiseCanExecuteChanged()
                        }} elseif ([System.Windows.Threading.Dispatcher]::CurrentDispatcher.CheckAccess()) {{
                            $this.psobject.RaiseCanExecuteChanged()
                            $this.psobject.Dispatcher = [System.Windows.Threading.Dispatcher]::CurrentDispatcher
                        }} else {{
                            [System.Windows.Threading.Dispatcher]::CurrentDispatcher.InvokeAsync($this.psobject.RaiseCanExecuteChangedDelegate)
                        }}' -f $_
                    )
                }
                $this | Add-Member @Splat
            }
        )
    }

    [void]RaiseCanExecuteChanged() {
        $eCanExecuteChanged = $this.psobject.InternalCanExecuteChanged
        if ($eCanExecuteChanged) {
            $eCanExecuteChanged.Invoke($this, [System.EventArgs]::Empty)
        }
    }

    [void]RemoveWorker() {
        $this.Workers--
    }

    [ViewModelBase]$Target
    [bool]$IsAsync = $false
    $Action
    $ActionObject
    $CanExecuteAction
    $Workers = 0
    $Throttle = 0
    $RaiseCanExecuteChangedDelegate
    $RemoveWorkerDelegate
}

function New-ViewModel {
    <#
        .SYNOPSIS
        Dynamically creates a class object that inherits ViewModeBase.
        Properties preceeed by `$this` used in Methods that aren't defined in PropertyNames will automatically be defined as a property of the class.
        Method overloads are not supported.

        .PARAMETER ClassName
        The name of the class
        'MyClass'

        Creates:
        class MyClass : ViewModeBase {
            MyClass() {}
        }

        .PARAMETER PropertyNames
        Takes an array of strings.
        @('property1', 'PropertY2')

        Creates:

        class ViewModel : ViewModelBase {
            $property1
            $PropertY2
        }

        .PARAMETER Methods
        Will also create class properties for methods that call $this.propertyname that isn't in $PropertyNames
        Requires a hashtable of name and it's methodbody as a scriptblock
        @(
            DoMethod = {return 'hello world'}
            OtherMethod = {$this.Property = 'foo'} # if '$Property' is not defined in PropertyNames, it will be added automatically.
        )

        Creates:

        class ViewModel : ViewModelBase {
            $Property
            [object]DoMethod() {
                return "hello world"
            }
            [void]OtherMethod() {
                $this.Property = 'foo'
            }
        }

        .PARAMETER Unbound
        Creates the class with no runspace affinity if $true. Otherwise class methods cannot be called when the UI is running.

        .PARAMETER CreateMethodCommand
        Creates a Command object for each method in $Methods that is populated with an [ActionCommand]

        class ViewModel : ViewModelBase {
            $DoMethodCommand
            [object]DoMethod() {
                return "hello world"
            }
        }

        .PARAMETER AsString
        Returns the full class definition as a string instead of the object.
    #>
    [CmdletBinding()]
    param (
        [string]$ClassName,
        [string[]]$PropertyNames,
        [pscustomobject[]]$Methods,
        [bool]$Unbound = $true,
        [bool]$CreateMethodCommand = $true,
        [switch]$AsString
    )

    $StringBuilder = [System.Text.StringBuilder]::new()

    # start class line
    $null = $StringBuilder.Append("class $ClassName")
    $null = $StringBuilder.Append(' : ViewModelBase')
    $null = $StringBuilder.AppendLine(' {')

    # class properties
    foreach ($Name in $PropertyNames) {
        if ($Name -notmatch '^\w+$') { throw 'property name can only contain letters and numbers' }
        $null = $StringBuilder.AppendLine(('${0}' -f $Name))
    }

    # base constructor
    $null = $StringBuilder.AppendLine(('{0}(){{}}' -f $ClassName))

    # methods
    foreach ($PSMethod in $Methods) {
        # Create a command property for the method and append 'Command' to the end.
        if ($CreateMethodCommand) {
            $null = $StringBuilder.AppendLine(('${0}Command' -f $PSMethod.MethodName))
        }

        if (($PSMethod.MethodBody.Ast.EndBlock.Statements.Where({ $null -ne $_.Pipeline })).Count -eq 0) {
            $null = $StringBuilder.AppendLine(('[void]{0}({1}) {{' -f $PSMethod.MethodName, $PSMethod.MethodParameterNames))
        } else {
            $null = $StringBuilder.AppendLine(('[object]{0}({1}) {{' -f $PSMethod.MethodName, $PSMethod.MethodParameterNames))
        }
        $null = $StringBuilder.AppendLine($($PSMethod.MethodBody.ToString().Trim()))
        $null = $StringBuilder.AppendLine('}')
    }

    # end class definition
    $null = $StringBuilder.AppendLine('}')

    # find all $this references from preliminary definition
    $DefinitionBeforeVariables = ([scriptblock]::Create($StringBuilder.ToString()))
    $ClassProperties = $DefinitionBeforeVariables.Ast.FindAll({ $args[0] -is [System.Management.Automation.Language.VariableExpressionAst] }, $true) | Where-Object { $_.VariablePath.UserPath -eq 'this' }

    # remove the newline and closing brace to add $this variables as properties from methods.
    $null = $StringBuilder.Remove($StringBuilder.Length - 3, 3)

    # get all unique $this properties and add them as $property if not added in $PropertyNames
    $UniqueProperties = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($Property in $ClassProperties.Parent.Member.Extent.Text) {
        if ([string]::IsNullOrWhiteSpace($Property)) { continue }
        if ($PropertyNames -contains $Property) { continue }
        $null = $UniqueProperties.Add($Property)
    }

    foreach ($Property in $UniqueProperties.GetEnumerator()) {
        $null = $StringBuilder.AppendLine('${0}' -f $Property)
    }

    # finish class definition
    $null = $StringBuilder.AppendLine('}')

    if ($AsString) {
        return $StringBuilder.ToString()
    }

    $Definition = ([scriptblock]::Create($StringBuilder.ToString()))
    . $Definition

    $DynamicClass = if ($Unbound) {
        New-UnboundClassInstance $ClassName
    } else {
        [activator]::CreateInstance($ClassName)
    }

    # add a command property for each method
    if ($CreateMethodCommand) {
        foreach ($PSMethod in $Methods) {
            $DynamicClass."$($PSMethod.MethodName)Command" = New-ActionCommand -MethodName $PSMethod.MethodName -Target $DynamicClass -Throttle $PSMethod.Throttle -IsAsync $PSMethod.IsAsync
        }
    }

    if (!$script:ViewModelThread['Pool'] -or $script:ViewModelThread['Pool'].IsDisposed) { Set-ViewModelPool }
    $DynamicClass.psobject.ViewModelThread = $script:ViewModelThread

    $DynamicClass
}

function New-ViewModelMethod {
    <#
        .SYNOPSIS
        Creates a pscustomobject to be consumed by New-ViewModel.
        Overloads are not supported.

        .PARAMETER MethodName
        Name of the method to be defined in the class by New-ViewModel.

        .PARAMETER MethodBody
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
        [string]$MethodName,
        [Parameter(Mandatory)]
        [scriptblock]$MethodBody,
        [string[]]$MethodParameterNames,
        [int]$Throttle = 0,
        [bool]$IsAsync = $true
    )

    $Parameters = foreach ($Name in $MethodParameterNames) {
        if ($Name -notmatch '^\w+$') { throw ('parameter name can only contain letters and numbers: "{0}"' -f $Name) }
        '${0}' -f $Name
    }
    $JoinedParameters = $Parameters -join ','

    [pscustomobject]@{
        MethodName = $MethodName
        MethodBody = $MethodBody.Ast.GetScriptBlock()
        MethodParameterNames = $JoinedParameters
        Throttle = $Throttle
        IsAsync = $IsAsync
    }
}

function Set-ViewModelPool {
    <#
        .SYNOPSIS
        Creates and opens the global runspacepool to be used by each viewmodel created by New-ViewModel.

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

function New-ActionCommand {
    <#
        .SYNOPSIS
        Creates an [ActionCommand] object with the provided method in $Target.

        .PARAMETER MethodName
        Name of the method in $Target.

        .PARAMETER IsAsync
        This signals the equivalent command to be invoked in another runspace if $true or on the console thread.

        .PARAMETER Target
        The class object of the method.

        .PARAMETER Throttle
        The max number of times the equivalent method command can be running at a given time.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$MethodName,
        [bool]$IsAsync = $true,
        [object]$Target,
        [int]$Throttle = 0
    )

    $Method = if ($Target.GetType().Name -eq 'PSCustomObject') {
        $Target.psobject.$MethodName
    } else {
        $Target.$MethodName
    }

    [ActionCommand]::new($Method, $IsAsync, $Target, $Throttle)
}

function New-WpfObject {
    <#
        .SYNOPSIS
        Creates a WPF object with given Xaml from a string or file
        Uses the dedicated wpf xaml reader rather than the xmlreader.

        .PARAMETER Xaml
        The xaml string for to be parsed.

        .PARAMETER Path
        The full name to the xaml file to be parsed.

        .PARAMETER DataContext
        The ViewModel class object that the WpfObject will use.

        .EXAMPLE
        New-WpfObject -Xaml $Xaml -BaseUri "$PSScriptRoot\" -DataContext $ViewModel
        New-WpfObject -Path $Path -BaseUri "C:\Test\Folder\"
    #>
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    param (
        [Parameter(Mandatory, ValueFromPipeline, Position = 0, ParameterSetName = 'HereString')]
        [string[]]$Xaml,
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, Position = 0, ParameterSetName = 'Path')]
        [ValidateScript({ Test-Path $_ })]
        [string[]]$Path,
        [string]$BaseUri,
        [ViewModelBase]$DataContext
    )

    process {
        $Xml = [xml]::new()
        $RawXaml = if ($PSBoundParameters.ContainsKey('Path')) {
            $Xml.Load($Path)
            $Xml.InnerXml
        } else {
            $Xml.LoadXml($Xaml)
            $Xml.InnerXml
        }

        $WpfObject = [System.Windows.Markup.XamlReader]::Parse($RawXaml)

        if ($DataContext) {
            # because $DataContext can be created unbound, it may not have the same dispatcher as $WpfObject so it is set here.
            $DataContext.psobject.Dispatcher = $WpfObject.Dispatcher
            $WpfObject.DataContext = $DataContext
        }

        $WpfObject
    }
}
