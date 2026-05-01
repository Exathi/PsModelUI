Import-Module .\PsModelUI

<#
    Normally this will yell at you since System.Windows.Data.IValueConverter is in PresentationFramework.dll.
    Classes are parsed before imports, with the exception of 'using', the class can't be defined here without first calling separately `Add-Type -AssemblyName PresentationFramework`
    New-Class can help work around that, otherwise define the class in another file and source it after the assemblies are loaded.
#>

# class CharConverter : System.Windows.Data.IValueConverter {
#     CharConverter() {}
#     [object]Convert([object]$Value, [Type]$TargetType, [object]$Parameter, [CultureInfo]$Culture) {
#         return [char]$Value
#     }

#     [object]ConvertBack([object]$Value, [Type]$TargetType, [object]$Parameter, [CultureInfo]$Culture) {
#         return $Value
#     }
# }

$CharConverterDefinition = New-Class -ClassName PSCharConverter -Inherits System.Windows.Data.IValueConverter -Methods @(
    New-ClassMethod -Name Convert -Body {
        param([object]$Value, [Type]$TargetType, [object]$Parameter, [CultureInfo]$Culture)
        return [char]$Value
    }
    New-ClassMethod -Name ConvertBack -Body {
        param([object]$Value, [Type]$TargetType, [object]$Parameter, [CultureInfo]$Culture)
        return $Value
    }
) -AsString -ExcludeScriptProperty
. ([scriptblock]::Create($CharConverterDefinition))

$Xaml = '<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    xmlns:local="clr-namespace:;assembly={0}"
    Title="PsModelUI 7.5"
    ThemeMode="Light"
    WindowStartupLocation="CenterScreen"
    Width="640"
    Height="480">
    <Window.Resources>
        <local:PSCharConverter x:Key="PowershellConverter" />
    </Window.Resources>
    <StackPanel HorizontalAlignment="Center" VerticalAlignment="Center">
        <TextBlock Text="{{Binding IntToChar, Converter={{StaticResource PowershellConverter}}}}" FontSize="20"/>
        <TextBox Text="{{Binding IntToChar, ValidatesOnExceptions=True, UpdateSourceTrigger=PropertyChanged}}" FontSize="20" Width="200" />
    </StackPanel>
</Window>
' -f [PSCharConverter].Assembly.FullName
$DataContext = (New-ViewModel -ClassName 'ConverterSample' -PropertyInit (New-ClassProperty -Name 'IntToChar' -Type int -Init { 97 } ))
$Window = New-WpfObject -Xaml $Xaml -DataContext $DataContext

$Window.ShowDialog()
