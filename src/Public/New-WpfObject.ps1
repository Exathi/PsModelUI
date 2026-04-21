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
        $Window = New-WpfObject -Xaml $Xaml -DataContext $ViewModel
        $ResourceDictionary = New-WpfObject -Path $Path
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
