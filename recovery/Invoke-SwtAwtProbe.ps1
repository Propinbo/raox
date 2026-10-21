[CmdletBinding()]
param(
    [string]$ToolchainRoot = (Join-Path (Split-Path -Parent $PSScriptRoot) '.build/platform-tools'),
    [string]$LogRoot = (Join-Path (Split-Path -Parent $PSScriptRoot) '.build/platform-probe'),
    [string]$ApplicationRoot
)
$ErrorActionPreference = 'Stop'
if ($ApplicationRoot) {
    $ApplicationRoot = (Resolve-Path -LiteralPath $ApplicationRoot).Path
    $javaDirectory = Join-Path $ApplicationRoot 'jre'
    $plugins = Join-Path $ApplicationRoot 'plugins'
} else {
    $ToolchainRoot = (Resolve-Path -LiteralPath $ToolchainRoot).Path
    $lock = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'platform/toolchains.lock.json') -Raw | ConvertFrom-Json
    $javaDirectory = Join-Path $ToolchainRoot $lock.jdk.directory
    $plugins = Join-Path $ToolchainRoot 'eclipse/eclipse/plugins'
}
$swt = @(Get-ChildItem -LiteralPath $plugins -Filter 'org.eclipse.swt_*.jar')
$fragment = @(Get-ChildItem -LiteralPath $plugins -Filter 'org.eclipse.swt.win32.win32.x86_64_*.jar')
if ($swt.Count -ne 1 -or $fragment.Count -ne 1) { throw 'Expected one Windows x64 SWT bundle and fragment.' }
$null = New-Item -ItemType Directory -Path $LogRoot -Force
$LogRoot = (Resolve-Path -LiteralPath $LogRoot).Path
$classpath = $swt[0].FullName + ';' + $fragment[0].FullName
& (Join-Path $javaDirectory 'bin/javac.exe') --release 21 -encoding UTF-8 -cp $classpath `
    -d $LogRoot (Join-Path $PSScriptRoot 'probes/SwtAwtProbe.java')
if ($LASTEXITCODE -ne 0) { throw 'SWT/AWT probe compilation failed.' }
$log = Join-Path $LogRoot 'stdout.log'
$errorLog = Join-Path $LogRoot 'stderr.log'
$probe = Start-Process -FilePath (Join-Path $javaDirectory 'bin/java.exe') -WindowStyle Hidden -PassThru `
    -ArgumentList @('-cp', ('"' + $classpath + ';' + $LogRoot + '"'), 'SwtAwtProbe') `
    -RedirectStandardOutput $log -RedirectStandardError $errorLog
if (-not $probe.WaitForExit(30000)) {
    $probe.Kill()
    throw "SWT/AWT probe timed out. See $LogRoot"
}
$probe.Refresh()
Get-Content -LiteralPath $log
Get-Content -LiteralPath $errorLog
if ($probe.ExitCode -ne 0) { throw "SWT/AWT probe exited with $($probe.ExitCode). See $LogRoot" }
