$ModuleName = 'PsModelUI'
$ModuleFolder = Join-Path -Path $PSScriptRoot -ChildPath $ModuleName
$RootModule = Join-Path -Path $ModuleFolder -ChildPath "$($ModuleName).psm1"
'Add-Type -AssemblyName PresentationFramework, WindowsBase -ErrorAction Stop' | Out-File -FilePath $RootModule -Encoding 'utf8NoBOM'

$BasePath = Join-Path -Path $PSScriptRoot -ChildPath 'src'
$ClassesPath = Join-Path -Path $BasePath -ChildPath 'Classes'
$PrivatePath = Join-Path -Path $BasePath -ChildPath 'Private'
$PublicPath = Join-Path -Path $BasePath -ChildPath 'Public'

$ClassOrder = 'ViewModelBase', 'ActionCommand'
$Files = @(
    Get-ChildItem -Path $ClassesPath -File -Filter '*.ps*1' | Sort-Object -Property @{e = { if ($ClassOrder.IndexOf($_.BaseName) -eq -1) { $_.BaseName } else { $ClassOrder.IndexOf($_.BaseName) } } }
    Get-ChildItem -Path $PrivatePath -File -Filter '*.ps*1'
    Get-ChildItem -Path $PublicPath -File -Filter '*.ps*1'
)

$Files | ForEach-Object {
    Get-Content -Path $_.FullName -Raw | Out-File -Path $RootModule -Append -Encoding 'utf8NoBOM'
}
