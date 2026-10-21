[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$JavaHome,
    [Parameter(Mandatory = $true)][string]$RunnerRoot,
    [Parameter(Mandatory = $true)][string]$AutRoot,
    [Parameter(Mandatory = $true)][string]$PluginsRoot,
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$LogRoot = (Join-Path (Split-Path -Parent $PSScriptRoot) 'ru.bmstu.rk9.rao.tests/target/rcptt'),
    [string]$Tests,
    [int]$TimeoutSeconds = 1200,
    [string]$LockRoot = $PSScriptRoot,
    [switch]$InstalledDistribution
)
$ErrorActionPreference = 'Stop'
foreach ($directory in @($JavaHome, $RunnerRoot, $AutRoot, $PluginsRoot, $RepoRoot)) {
    if (-not (Test-Path -LiteralPath $directory -PathType Container)) { throw "Missing directory: $directory" }
}
$JavaHome = (Resolve-Path -LiteralPath $JavaHome).Path
$RunnerRoot = (Resolve-Path -LiteralPath $RunnerRoot).Path
$AutRoot = (Resolve-Path -LiteralPath $AutRoot).Path
$PluginsRoot = (Resolve-Path -LiteralPath $PluginsRoot).Path
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$null = New-Item -ItemType Directory -Path $LogRoot -Force
$LogRoot = (Resolve-Path -LiteralPath $LogRoot).Path
if ($InstalledDistribution) {
    & (Join-Path $PSScriptRoot 'Test-WindowsDistribution.ps1') -ApplicationRoot $AutRoot -AllowRuntimeState
    # The runner still has its own independently pinned platform.
    $runnerLock = @(Import-Csv -LiteralPath (Join-Path $LockRoot 'rcptt-plugins.lock.csv'))
    foreach ($entry in $runnerLock) {
        if ((Get-FileHash -LiteralPath (Join-Path $RunnerRoot $entry.path)).Hash -ne $entry.sha256) {
            throw "RCPTT runner differs: $($entry.path)"
        }
    }
} else {
    & (Join-Path $PSScriptRoot 'Test-UiPlatform.ps1') -AutRoot $AutRoot -RunnerRoot $RunnerRoot -LockRoot $LockRoot
}
$java = Join-Path $JavaHome 'bin/java.exe'
$launchers = @(Get-ChildItem -LiteralPath (Join-Path $RunnerRoot 'plugins') -Filter 'org.eclipse.equinox.launcher_*.jar')
if ($launchers.Count -ne 1) { throw 'Expected exactly one RCPTT Equinox launcher.' }
$runRoot = Join-Path $LogRoot ((Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '-rcptt')
$injection = Join-Path $runRoot 'injection'
New-Item -ItemType Directory -Path $injection -Force | Out-Null
# RCPTT builds its own target platform and does not discover AUT dropins.
# Exclude the duplicate runtime without a version (same OSGi symbolic name).
$plugins = if ($InstalledDistribution) {
    @(Get-ChildItem -LiteralPath (Join-Path $AutRoot 'plugins') -Filter 'ru.bmstu.*_3.9.0.jar')
} else { @(Get-ChildItem -LiteralPath $PluginsRoot -Filter '*-3.9.0.jar') }
if ($plugins.Count -ne 4) { throw 'Expected the four versioned Rao 3.9.0 plugins.' }
if (-not $InstalledDistribution) { $plugins | Copy-Item -Destination $injection }
$importSource = Join-Path $runRoot 'import-source/ui_import'
New-Item -ItemType Directory -Path (Join-Path $importSource 'src-gen') -Force | Out-Null
$fixture = Join-Path $RepoRoot 'ru.bmstu.rk9.rao.rcptt/fixtures/ui_import'
Copy-Item -LiteralPath (Join-Path $fixture '.project'), (Join-Path $fixture 'ui_import.rao') -Destination $importSource
# Run the exact model printed in the Windows guide; do not maintain a UI-only copy.
$guide = Get-Content -LiteralPath (Join-Path $RepoRoot 'docs/user_guide/quick_start.html') -Raw -Encoding utf8
$example = [regex]::Match($guide, '(?s)<code class="rao" id="quickstart-source">(.*?)</code>')
if (-not $example.Success) { throw 'Missing quick start model in the documentation.' }
[Net.WebUtility]::HtmlDecode($example.Groups[1].Value) |
    Set-Content -LiteralPath (Join-Path (Split-Path -Parent $importSource) 'quickstart.rao') -Encoding utf8
$runtimeFile = if ($InstalledDistribution) { Join-Path $AutRoot 'plugins/ru.bmstu.rk9.rao.lib_3.9.0.jar' }
    else { Join-Path $injection 'ru.bmstu.rk9.rao.lib-3.9.0.jar' }
$runtimePath = [System.Security.SecurityElement]::Escape($runtimeFile.Replace('\', '/'))
(Get-Content -LiteralPath (Join-Path $fixture '.classpath.template') -Raw).Replace('@@RAOX_RUNTIME@@', $runtimePath) |
    Set-Content -LiteralPath (Join-Path $importSource '.classpath') -Encoding utf8
$log = Join-Path $runRoot 'runner.log'
$arguments = @('-Xmx1024m', '-Dfile.encoding=UTF-8', '-jar', $launchers[0].FullName,
    '-application', 'org.eclipse.rcptt.runner.headless', '-data', (Join-Path $runRoot 'runner-workspace'),
    '-aut', $AutRoot, '-autVM', $JavaHome,
    '-autWsPrefix', (Join-Path $runRoot 'aut-workspace-'), '-autConsolePrefix', (Join-Path $runRoot 'aut-out-'),
    '-htmlReport', (Join-Path $runRoot 'results.html'), '-junitReport', (Join-Path $runRoot 'results.xml'),
    '-import', (Join-Path $RepoRoot 'ru.bmstu.rk9.rao.rcptt'),
    '-timeout', "$TimeoutSeconds", '-connectTimeout', '60')
if (-not $InstalledDistribution) { $arguments += @('-injection:dir', $injection) }
if ($Tests) { $arguments += @('-tests', $Tests) }
& $java @arguments *> $log
$runnerExit = $LASTEXITCODE
$reports = @(Get-ChildItem -LiteralPath $runRoot -Filter '*junit.xml')
$counts = [ordered]@{ tests = 0; failures = 0; errors = 0; skipped = 0 }
foreach ($file in $reports) {
    [xml]$report = Get-Content -LiteralPath $file.FullName -Raw -Encoding utf8
    foreach ($suite in $report.SelectNodes('//testsuite')) {
        foreach ($key in @('tests', 'failures', 'errors', 'skipped')) {
            $counts[$key] += [int]$suite.GetAttribute($key)
        }
    }
}
[ordered]@{ exit_code = $runnerExit; java = $java; runner = $RunnerRoot; aut = $AutRoot
    installed_distribution = [bool]$InstalledDistribution
    plugins = @($plugins | ForEach-Object { @{name=$_.Name; sha256=(Get-FileHash $_.FullName).Hash} })
    counts = $counts; log = $log
} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $runRoot 'run.json') -Encoding utf8
Get-Content -LiteralPath $log -Tail 30
Write-Output "RCPTT evidence: $runRoot"
if ($runnerExit -ne 0 -or $counts.tests -eq 0 -or (-not $Tests -and $counts.tests -ne 43) -or
    $counts.failures -gt 0 -or $counts.errors -gt 0 -or $counts.skipped -gt 0) {
    throw "RCPTT failed or did not run tests. See $runRoot"
}
