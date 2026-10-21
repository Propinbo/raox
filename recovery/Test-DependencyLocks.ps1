[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$CacheRoot)

$ErrorActionPreference = 'Stop'
$CacheRoot = (Resolve-Path -LiteralPath $CacheRoot).Path
$lock = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'p2-bundles.lock.json') -Raw | ConvertFrom-Json
$known = @{}
foreach ($bundle in $lock.bundles) {
    $known["$($bundle.id)/$($bundle.version)"] = $bundle
}
$checked = 0
foreach ($file in Get-ChildItem -LiteralPath (Join-Path $CacheRoot 'p2/osgi/bundle') -Filter '*.jar' -Recurse) {
    $key = "$($file.Directory.Parent.Name)/$($file.Directory.Name)"
    if (-not $known.ContainsKey($key)) { throw "Unpinned p2 bundle: $key" }
    if ((Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash -ne $known[$key].sha256) {
        throw "p2 bundle checksum mismatch: $key"
    }
    $checked++
}
if ($checked -eq 0) { throw 'No p2 bundles were verified.' }
Write-Output "Verified SHA-256 of $checked pinned p2 bundles."

# Maven generator/plugin dependencies form a separate classpath from p2. Lock their
# immutable binaries too; range discovery may download additional candidate POMs.
$mavenLock = @(Import-Csv -LiteralPath (Join-Path $PSScriptRoot 'maven-artifacts.lock.csv'))
$mavenFiles = @(Get-ChildItem -LiteralPath $CacheRoot -File -Recurse |
    Where-Object {
        $relative = $_.FullName.Substring($CacheRoot.Length + 1).Replace('\', '/')
        $relative -notmatch '^(p2|\.cache|\.meta|\.wrapper)/' -and $_.Extension -in @('.jar', '.zip')
    })
$expectedPaths = @{}
foreach ($entry in $mavenLock) { $expectedPaths[$entry.path] = $entry.sha256 }
if ($mavenFiles.Count -ne $mavenLock.Count) {
    throw "Maven cache differs from the locked dependency set ($($mavenFiles.Count) artifacts, expected $($mavenLock.Count)). Use a dedicated empty cache."
}
foreach ($file in $mavenFiles) {
    $relative = $file.FullName.Substring($CacheRoot.Length + 1).Replace('\', '/')
    if (-not $expectedPaths.ContainsKey($relative)) { throw "Unpinned Maven artifact: $relative" }
    if ((Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash -ne $expectedPaths[$relative]) {
        throw "Maven artifact checksum mismatch: $relative"
    }
}
Write-Output "Verified SHA-256 of $($mavenFiles.Count) pinned Maven artifacts."
