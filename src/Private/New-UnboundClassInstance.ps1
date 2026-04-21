$script:Powershell = $null

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
