[CmdletBinding()]
param(
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$ToolchainRoot = (Join-Path (Split-Path -Parent $PSScriptRoot) '.build/platform-tools'),
    [string]$OutputRoot = (Join-Path (Split-Path -Parent $PSScriptRoot) 'assembly/target/windows-x64')
)
$ErrorActionPreference = 'Stop'
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$ToolchainRoot = (Resolve-Path -LiteralPath $ToolchainRoot).Path
$repository = (Resolve-Path -LiteralPath (Join-Path $RepoRoot 'raox.repository/target/repository')).Path
$javaHome = Join-Path $ToolchainRoot 'jdk-21.0.12.1+1'
$bootstrap = Join-Path $ToolchainRoot 'eclipse/eclipse'
$launcher = @(Get-ChildItem -LiteralPath (Join-Path $bootstrap 'plugins') -Filter 'org.eclipse.equinox.launcher_*.jar')
if ($launcher.Count -ne 1) { throw 'Expected one pinned p2 director launcher; run Initialize-Platform.ps1 -IncludeUi.' }
# The bootstrap is a build tool only. The application is provisioned into a fresh
# directory entirely from our assembled local p2 repository, with no dropins.
$null = New-Item -ItemType Directory -Path $OutputRoot -Force
$OutputRoot = (Resolve-Path -LiteralPath $OutputRoot).Path
$destination = Join-Path $OutputRoot 'raox'
if (Test-Path -LiteralPath $destination) { throw "Output already exists; select a fresh OutputRoot: $destination" }
$log = Join-Path $OutputRoot 'director.log'
$repoUri = ([Uri]::new($repository + [IO.Path]::DirectorySeparatorChar)).AbsoluteUri
$roots = 'org.eclipse.platform.ide/4.37.0.I20250905-0730,org.eclipse.jdt.feature.group/3.20.300.v20250905-1111,org.eclipse.xtend.sdk.feature.group/2.40.0.v20250825-0355,ru.bmstu.rk9.rao.sdk.feature.group/3.9.0'
& (Join-Path $javaHome 'bin/java.exe') '-Dfile.encoding=UTF-8' '-jar' $launcher[0].FullName `
    '-application' 'org.eclipse.equinox.p2.director' '-nosplash' '-consoleLog' `
    '-repository' $repoUri '-installIU' $roots '-destination' $destination `
    '-profile' 'RaoX' '-profileProperties' 'org.eclipse.update.install.features=true' `
    '-p2.os' 'win32' '-p2.ws' 'win32' '-p2.arch' 'x86_64' '-roaming' *> $log
if ($LASTEXITCODE -ne 0) { throw "p2 director failed: $log" }
Copy-Item -LiteralPath $javaHome -Destination (Join-Path $destination 'jre') -Recurse
$appLauncher = @(Get-ChildItem -LiteralPath (Join-Path $destination 'plugins') -Filter 'org.eclipse.equinox.launcher_*.jar')
$nativeLauncher = @(Get-ChildItem -LiteralPath (Join-Path $destination 'plugins') -Directory -Filter 'org.eclipse.equinox.launcher.win32.win32.x86_64_*')
if ($appLauncher.Count -ne 1 -or $nativeLauncher.Count -ne 1) { throw 'Incomplete native launcher installation.' }
@"
-startup
plugins/$($appLauncher[0].Name)
--launcher.library
plugins/$($nativeLauncher[0].Name)
-product
org.eclipse.platform.ide
-perspective
ru.bmstu.rk9.rao.ui.perspective
--launcher.defaultAction
openFile
-vm
jre/bin/javaw.exe
-vmargs
-Xms256m
-Xmx2048m
-Dfile.encoding=UTF-8
-Dosgi.requiredJavaVersion=21
--add-modules=ALL-SYSTEM
"@ | Set-Content -LiteralPath (Join-Path $destination 'eclipse.ini') -Encoding utf8NoBOM
# Console applications such as p2 director do not accept the workbench's
# -perspective option. Keep a console-specific ini with the same bundled VM.
$consoleIni = [Collections.Generic.List[string]]::new()
$lines = @(Get-Content -LiteralPath (Join-Path $destination 'eclipse.ini'))
for ($i=0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -eq '-perspective') { $i++; continue }
    $consoleIni.Add($lines[$i])
}
$consoleIni | Set-Content -LiteralPath (Join-Path $destination 'eclipsec.ini') -Encoding utf8NoBOM
& (Join-Path $PSScriptRoot 'Enable-Utf8Launchers.ps1') -ApplicationRoot $destination
Copy-Item -LiteralPath (Join-Path $RepoRoot 'LICENSE') -Destination $destination
Copy-Item -LiteralPath (Join-Path $RepoRoot 'recovery/licenses') -Destination $destination -Recurse
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Enable-Utf8Launchers.ps1') -Destination (Join-Path $destination 'licenses')
Copy-Item -LiteralPath (Join-Path $RepoRoot 'recovery/THIRD-PARTY.md') -Destination $destination
Copy-Item -LiteralPath (Join-Path $RepoRoot 'recovery/embedded-libraries.lock.json') -Destination $destination
@'
Rao X 3.9.0 - Windows x64 / Java 21

Extract the entire ZIP to a writable folder, then run eclipse.exe.
The Java runtime is included; JAVA_HOME and a separate Eclipse are unnecessary.
Select a new workspace. Use File > New > Project... > Rao X > Rao X Project.
Source code, licenses and notices for bundled libraries are in licenses/ and
inside each Eclipse plugin. See THIRD-PARTY.md for provenance and limitations.
'@ | Set-Content -LiteralPath (Join-Path $destination 'README.txt') -Encoding utf8NoBOM
$inventory = @(Get-ChildItem -LiteralPath $destination -Recurse -File | Sort-Object FullName | ForEach-Object {
    [ordered]@{ path = $_.FullName.Substring($destination.Length + 1).Replace('\','/');
        bytes = $_.Length; sha256 = (Get-FileHash -LiteralPath $_.FullName).Hash.ToLowerInvariant() }
})
[ordered]@{ platform = 'win32/win32/x86_64'; java = 'Temurin 21.0.12.1+1';
    roots = $roots; files = $inventory } | ConvertTo-Json -Depth 5 |
    Set-Content -LiteralPath (Join-Path $destination 'distribution-manifest.json') -Encoding utf8
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = Join-Path $OutputRoot 'raox-3.9.0-windows-x86_64.zip'
[IO.Compression.ZipFile]::CreateFromDirectory($destination, $archive, [IO.Compression.CompressionLevel]::Optimal, $true)
$result = [ordered]@{ archive = $archive; bytes = (Get-Item -LiteralPath $archive).Length;
    sha256 = (Get-FileHash -LiteralPath $archive).Hash.ToLowerInvariant(); files = $inventory.Count;
    director_log = $log; application = $destination }
$result | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $OutputRoot 'distribution.json') -Encoding utf8
$result
