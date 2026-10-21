[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$AutRoot,
    [Parameter(Mandatory = $true)][string]$RunnerRoot
)

$ErrorActionPreference = 'Stop'
foreach ($name in @('eclipse', 'rcptt')) {
    $root = if ($name -eq 'eclipse') { $AutRoot } else { $RunnerRoot }
    $root = (Resolve-Path -LiteralPath $root).Path
    $inventory = @(Import-Csv -LiteralPath (Join-Path $PSScriptRoot "$name-plugins.lock.csv"))
    $actual = @(Get-ChildItem -LiteralPath (Join-Path $root 'plugins') -File -Recurse)
    if ($actual.Count -ne $inventory.Count) { throw "Unexpected $name plugin file count: $($actual.Count)" }
    foreach ($entry in $inventory) {
        $file = Join-Path $root $entry.path
        if (-not (Test-Path -LiteralPath $file -PathType Leaf) -or
            (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash -ne $entry.sha256) {
            throw "Platform differs from the pinned $name distribution: $($entry.path)"
        }
    }
    Write-Output "Verified $name platform: $($inventory.Count) plugin files."
}
