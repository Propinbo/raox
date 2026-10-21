[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$ApplicationRoot, [switch]$AllowRuntimeState)
$ErrorActionPreference = 'Stop'
$ApplicationRoot = (Resolve-Path -LiteralPath $ApplicationRoot).Path
$manifest = Get-Content -LiteralPath (Join-Path $ApplicationRoot 'distribution-manifest.json') -Raw | ConvertFrom-Json
$stateFiles = 0
foreach ($file in $manifest.files) {
    if ($AllowRuntimeState -and $file.path -match '^p2/.*/profileRegistry/[^/]+/\.data/\.settings/[^/]+\.prefs$') {
        $stateFiles++; continue
    }
    $path = Join-Path $ApplicationRoot $file.path
    if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or
        (Get-Item -LiteralPath $path).Length -ne $file.bytes -or
        (Get-FileHash -LiteralPath $path).Hash -ne $file.sha256) { throw "Distribution differs: $($file.path)" }
}
foreach ($required in @('eclipse.exe','eclipsec.exe','eclipsec.ini','native-launchers.json','jre/bin/java.exe','jre/bin/javac.exe','jre/legal','licenses','LICENSE')) {
    if (-not (Test-Path -LiteralPath (Join-Path $ApplicationRoot $required))) { throw "Missing: $required" }
}
$ini = Get-Content -LiteralPath (Join-Path $ApplicationRoot 'eclipse.ini') -Raw
if ($ini -notmatch '(?m)^jre/bin/javaw.exe\r?$') { throw 'The launcher must use its relative bundled VM.' }
foreach ($id in @('ru.bmstu.rk9.rao','ru.bmstu.rk9.rao.lib','ru.bmstu.rk9.rao.ui','ru.bmstu.rk9.raox.plugins.game5')) {
    if (@(Get-ChildItem -LiteralPath (Join-Path $ApplicationRoot 'plugins') -Filter ($id + '_3.9.0.jar')).Count -ne 1) {
        throw "Missing installed Rao plugin: $id"
    }
}
if (@(Get-ChildItem -LiteralPath (Join-Path $ApplicationRoot 'plugins') -Filter 'org.eclipse.xtend.ide_*.jar').Count -ne 1) {
    throw 'Missing Xtend IDE provider for the model XTEND_CONTAINER classpath.'
}
[pscustomobject]@{ application = $ApplicationRoot; files_verified = $manifest.files.Count - $stateFiles;
    mutable_state_files = $stateFiles; platform = $manifest.platform }
