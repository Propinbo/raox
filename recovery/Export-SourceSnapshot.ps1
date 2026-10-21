[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Destination,
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
if ((Test-Path -LiteralPath $Destination) -and @(Get-ChildItem -LiteralPath $Destination -Force).Count -gt 0) {
    throw "Source snapshot destination must be empty: $Destination"
}
$null = New-Item -ItemType Directory -Path $Destination -Force
$Destination = (Resolve-Path -LiteralPath $Destination).Path
# Read the working files as well as untracked recovery changes. Never copy ignored build output.
$files = & git -c core.quotepath=false -C $RepoRoot ls-files --cached --others --exclude-standard
if ($LASTEXITCODE -ne 0) { throw 'git ls-files failed.' }
$manifest = foreach ($relativePath in $files | Sort-Object -Unique) {
    $source = Join-Path $RepoRoot $relativePath
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { continue }
    $target = Join-Path $Destination $relativePath
    $null = New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force
    Copy-Item -LiteralPath $source -Destination $target
    [pscustomobject]@{ path = $relativePath; sha256 = (Get-FileHash -LiteralPath $target).Hash.ToLowerInvariant() }
}
$outputs = @(Get-ChildItem -LiteralPath $Destination -Recurse -File |
    Where-Object { $_.Extension -eq '.class' -or $_.FullName -match '[\\/]target[\\/]' })
if ($outputs.Count -gt 0) { throw 'Source snapshot unexpectedly contains generated build output.' }
[ordered]@{
    created_at_utc = [DateTime]::UtcNow.ToString('o')
    repository_head = (& git -C $RepoRoot rev-parse HEAD)
    destination = $Destination
    generated_outputs = $outputs.Count
    files = @($manifest)
} | ConvertTo-Json -Depth 5
