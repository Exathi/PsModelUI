Import-Module .\PsModelUI

$Xaml = [xml]::new()
$Xaml.LoadXml(@'
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    Title="PsModelUI 7.5" ThemeMode="Dark" WindowStartupLocation="CenterScreen" Width="640" Height="480">
	<StackPanel HorizontalAlignment="Center">
		 <TextBlock Text="{Binding TextProperty, Mode=TwoWay, UpdateSourceTrigger=PropertyChanged, StringFormat={}{0:F2}}" />
		 <TextBox Name="TextBoxBinder" Text="{Binding TextProperty, Mode=TwoWay, UpdateSourceTrigger=PropertyChanged}" Margin="0,10,0,0" />
         <Slider Minimum="0"
                 Maximum="255"
                 Value="{Binding ElementName=TextBoxBinder, Path=Text}"
                 IsSnapToTickEnabled="True"
                 TickFrequency="1"
                 VerticalAlignment="Center" />
	</StackPanel>
</Window>
'@)

$ViewModel = New-ViewModel -ClassName 'ViewModel' -PropertyInit @{
    Name = 'TextProperty'
    Type = [byte]
    Init = { 123 }
    # ExcludePrefix = $true # if true then textblock will never update because PropertyChanged is never called for TextProperty. It has have a different backing field name.
}

$Window = New-WpfObject -Xaml $Xaml.InnerXml -DataContext $ViewModel
$Window.ShowDialog()
