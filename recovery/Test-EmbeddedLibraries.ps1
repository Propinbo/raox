[CmdletBinding()]
param([string]$RepoRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$lock = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'embedded-libraries.lock.json') -Raw | ConvertFrom-Json
$expected = @($lock.libraries | ForEach-Object { $_.path })
$actual = @(@('ru.bmstu.rk9.rao.lib/thirdparty','ru.bmstu.rk9.rao.ui/thirdparty','ru.bmstu.rk9.rao.plugins/raox-game5/third-party') |
    ForEach-Object { Get-ChildItem -LiteralPath (Join-Path $RepoRoot $_) -Recurse -Filter '*.jar' -File } |
    ForEach-Object { $_.FullName.Substring($RepoRoot.Length + 1).Replace('\','/') })
if (@(Compare-Object $expected $actual).Count) { throw 'Embedded binary set differs from the reviewed inventory.' }
$files = @($lock.libraries) + @($lock.source_files) + @($lock.license_files)
foreach ($entry in $files) {
    $path = Join-Path $RepoRoot $entry.path
    if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or
        (Get-FileHash -LiteralPath $path).Hash -ne $entry.sha256) { throw "Reviewed dependency checksum differs: $($entry.path)" }
}
Write-Output "Verified $($lock.libraries.Count) embedded JARs and $($files.Count - $lock.libraries.Count) source/license files."
