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
$repacked = @()
foreach ($file in Get-ChildItem -LiteralPath (Join-Path $CacheRoot 'p2/osgi/bundle') -Filter '*.jar' -Recurse) {
    $key = "$($file.Directory.Parent.Name)/$($file.Directory.Name)"
    if (-not $known.ContainsKey($key)) { throw "Unpinned p2 bundle: $key" }
    if ((Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash -ne $known[$key].sha256) {
        $contentHash = & (Join-Path $PSScriptRoot 'Get-JarContentHash.ps1') -Path $file.FullName
        if ($contentHash -ne $known[$key].content_sha256) {
            throw "p2 bundle checksum mismatch (including entry contents): $key"
        }
        $repacked += $key
    }
    $checked++
}
if ($checked -ne $lock.bundles.Count) {
    throw "Expected all $($lock.bundles.Count) pinned p2 bundles; found $checked."
}
Write-Host "Verified SHA-256 of $checked pinned p2 bundles ($($repacked.Count) equivalent ZIP representations)."

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
Write-Host "Verified SHA-256 of $($mavenFiles.Count) pinned Maven artifacts."
[pscustomobject]@{ p2_bundles = $checked; p2_equivalent_zip_representations = @($repacked); maven_binaries = $mavenFiles.Count }
