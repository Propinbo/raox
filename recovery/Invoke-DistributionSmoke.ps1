[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ArchivePath,
    [string]$Destination = (Join-Path ([IO.Path]::GetTempPath()) ('Rao X проверка ' + (Get-Date -Format 'yyyyMMdd-HHmmss')))
)
$ErrorActionPreference = 'Stop'
$ArchivePath = (Resolve-Path -LiteralPath $ArchivePath).Path
if (Test-Path -LiteralPath $Destination) { throw "Smoke destination must be fresh: $Destination" }
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::ExtractToDirectory($ArchivePath, $Destination)
$app = Join-Path $Destination 'raox'
$verified = & (Join-Path $PSScriptRoot 'Test-WindowsDistribution.ps1') -ApplicationRoot $app
$start = [Diagnostics.ProcessStartInfo]::new((Join-Path $app 'eclipsec.exe'))
$start.UseShellExecute = $false
$start.CreateNoWindow = $true
$start.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
$start.RedirectStandardOutput = $true
$start.RedirectStandardError = $true
$start.WorkingDirectory = $Destination
$start.Environment.Remove('JAVA_HOME') | Out-Null
$start.Environment.Remove('JDK_HOME') | Out-Null
$start.Environment['PATH'] = Join-Path $env:SystemRoot 'System32'
foreach ($arg in @('--launcher.ini',(Join-Path $app 'eclipsec.ini'),'--launcher.suppressErrors',
    '-nosplash','-consoleLog','-application','org.eclipse.equinox.p2.director',
    '-listInstalledRoots','-data',(Join-Path $Destination 'native-workspace'))) { $start.ArgumentList.Add($arg) }
$process = [Diagnostics.Process]::Start($start)
$stdout = $process.StandardOutput.ReadToEndAsync()
$stderr = $process.StandardError.ReadToEndAsync()
if (-not $process.WaitForExit(60000)) {
    $process.Kill($true)
    $process.WaitForExit()
    ($stdout.GetAwaiter().GetResult() + $stderr.GetAwaiter().GetResult()) |
        Set-Content -LiteralPath (Join-Path $Destination 'native-launch.log') -Encoding utf8
    throw "Native launcher smoke timed out: $Destination/native-launch.log"
}
$output = $stdout.GetAwaiter().GetResult() + $stderr.GetAwaiter().GetResult()
$output | Set-Content -LiteralPath (Join-Path $Destination 'native-launch.log') -Encoding utf8
if ($process.ExitCode -ne 0 -or $output -notmatch 'ru.bmstu.rk9.rao.sdk.feature.group/3.9.0') {
    throw "Native launcher failed ($($process.ExitCode)): $Destination/native-launch.log"
}
$result = [ordered]@{ archive_sha256 = (Get-FileHash -LiteralPath $ArchivePath).Hash.ToLowerInvariant();
    application = $app; working_directory = $Destination; java_home_removed = $true;
    path_contains_java = $false; native_exit_code = $process.ExitCode;
    installed_roots = $output.Trim(); verified = $verified }
$result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $Destination 'smoke.json') -Encoding utf8
$result
