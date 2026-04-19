$ModulePath = "$PSScriptRoot\PsModelUI"
Publish-Module -Path $ModulePath -NuGetApiKey $Env:APIKEY
