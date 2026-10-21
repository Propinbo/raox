[CmdletBinding()]
param(
    [string]$ToolchainRoot = (Join-Path (Split-Path -Parent $PSScriptRoot) '.build/tools'),

    [string]$CacheRoot = (Join-Path (Split-Path -Parent $PSScriptRoot) '.build/m2'),

    [ValidateSet('validate', 'package', 'verify')]
    [string]$Goal = 'package',

    [switch]$Clean,

    [switch]$RequireEmptyCache,

    [switch]$Offline,

    [ValidateRange(0, 5)]
    [int]$NetworkRetries = 3,

    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot),

    [string]$LogRoot = (Join-Path (Split-Path -Parent $PSScriptRoot) '.build/evidence'),

    [switch]$Platform
)

$ErrorActionPreference = 'Stop'
$ToolchainRoot = (Resolve-Path -LiteralPath $ToolchainRoot).Path
$lockRoot = if ($Platform) { Join-Path $PSScriptRoot 'platform' } else { $PSScriptRoot }
if ($Platform) { & (Join-Path $PSScriptRoot 'Test-EmbeddedLibraries.ps1') -RepoRoot $RepoRoot }
$toolchains = Get-Content -LiteralPath (Join-Path $lockRoot 'toolchains.lock.json') -Raw | ConvertFrom-Json
$javaDirectory = Join-Path $ToolchainRoot $toolchains.jdk.directory
$javaExecutable = Join-Path $javaDirectory 'bin\java.exe'
$mavenExecutable = Join-Path $RepoRoot 'mvnw.cmd'
foreach ($requiredFile in @($javaExecutable, $mavenExecutable, (Join-Path $RepoRoot 'pom.xml'))) {
    if (-not (Test-Path -LiteralPath $requiredFile -PathType Leaf)) {
        throw "Required file does not exist: $requiredFile"
    }
}

$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$mavenExecutable = Join-Path $RepoRoot 'mvnw.cmd'
if ($RepoRoot -match '[^\x00-\x7F]') {
    throw 'The legacy ANTLR generator requires an ASCII source path. Move the checkout to a path without Cyrillic or other non-ASCII characters. Unicode identifiers in .rao models are supported.'
}
$cacheInitiallyEmpty = -not (Test-Path -LiteralPath $CacheRoot) -or
    @(Get-ChildItem -LiteralPath $CacheRoot -Force).Count -eq 0
if ($RequireEmptyCache -and -not $cacheInitiallyEmpty) {
    throw "A genuinely empty cache was requested; directory contains files: $CacheRoot"
}
$null = New-Item -ItemType Directory -Path $CacheRoot -Force
$null = New-Item -ItemType Directory -Path $LogRoot -Force
$CacheRoot = (Resolve-Path -LiteralPath $CacheRoot).Path
$LogRoot = (Resolve-Path -LiteralPath $LogRoot).Path
$settingsFile = Join-Path $PSScriptRoot 'maven-settings.xml'
$repositoryDirectory = $CacheRoot
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
$logFile = Join-Path $LogRoot "$stamp-$Goal.log"
$resultFile = Join-Path $LogRoot "$stamp-$Goal.json"

$previousJavaHome = $env:JAVA_HOME
$previousMavenOpts = $env:MAVEN_OPTS
$previousMavenUserHome = $env:MAVEN_USER_HOME
$startedAt = [DateTime]::UtcNow
$exitCode = $null
$artifact = $null
$unitTests = $null
$dependencyVerification = $null
$succeeded = $false
$failure = $null
$locationPushed = $false
$mavenGoals = @()
if ($Clean) { $mavenGoals += 'clean' }
$mavenGoals += $Goal
$attempts = @()
try {
    $env:JAVA_HOME = $javaDirectory
    $env:MAVEN_USER_HOME = Join-Path $CacheRoot '.wrapper'
    if ($Offline -and -not $Platform) {
        & (Join-Path $PSScriptRoot 'Initialize-P2MetadataCache.ps1') -CacheRoot $CacheRoot -Offline
    }
    $env:MAVEN_OPTS = '-Xmx1024m -Dfile.encoding=UTF-8 -Djava.net.preferIPv4Stack=true -Dmaven.wagon.http.retryHandler.count=3 -Dmaven.wagon.http.connectionTimeout=20000 -Dmaven.wagon.http.readTimeout=60000 -Dorg.eclipse.ecf.provider.filetransfer.httpclient4.browse.connectTimeout=20000 -Dorg.eclipse.ecf.provider.filetransfer.httpclient4.retrieve.connectTimeout=20000 -Dorg.eclipse.ecf.provider.filetransfer.httpclient4.retrieve.readTimeout=60000 -Dorg.eclipse.equinox.p2.transport.ecf.retry=3'
    if ($Platform) { $env:MAVEN_OPTS += ' -Daether.connector.connectTimeout=20000 -Daether.connector.requestTimeout=60000 -Declipse.p2.mirrors=false' }
    Push-Location -LiteralPath $RepoRoot
    $locationPushed = $true
    & $mavenExecutable -version *> $logFile
    if ($LASTEXITCODE -ne 0) { throw "Unable to start Maven. Full log: $logFile" }
    if (-not $Platform -and -not (Select-String -LiteralPath $logFile -Pattern 'Java version: 1\.8\.' -Quiet)) {
        throw "This build requires JDK 8. Full log: $logFile"
    }
    if ($Platform) {
        if (-not (Select-String -LiteralPath $logFile -SimpleMatch "Apache Maven $($toolchains.maven.version)" -Quiet) -or
            -not (Select-String -LiteralPath $logFile -SimpleMatch 'Java version: 21.0.12.1' -Quiet)) {
            throw "Expected Maven $($toolchains.maven.version) and $($toolchains.jdk.version). Full log: $logFile"
        }
    } elseif (-not (Select-String -LiteralPath $logFile -Pattern 'Apache Maven 3\.3\.9' -Quiet) -or
        -not (Select-String -LiteralPath $logFile -Pattern '1\.8\.0_504, vendor: Temurin' -Quiet) -or
        -not (Select-String -LiteralPath $logFile -Pattern 'arch: "amd64"' -Quiet)) {
        throw "Expected Maven 3.3.9 and Temurin JDK 8u504 x64. Full log: $logFile"
    }
    $mavenArguments = @('-B', '-e', '-s', $settingsFile, '-gs', $settingsFile, "-Dmaven.repo.local=$repositoryDirectory")
    if ($Offline) { $mavenArguments += '-o' }
    for ($attempt = 0; $attempt -le $NetworkRetries; $attempt++) {
        $attemptLog = Join-Path $LogRoot "$stamp-$Goal-attempt-$($attempt + 1).log"
        & $mavenExecutable @mavenArguments @mavenGoals *> $attemptLog
        $exitCode = $LASTEXITCODE
        Get-Content -LiteralPath $attemptLog | Add-Content -LiteralPath $logFile -Encoding utf8
        $networkFailure = Select-String -LiteralPath $attemptLog -Quiet -Pattern `
            'Could not transfer artifact|UnknownHostException|SocketTimeoutException|ConnectException|ConnectTimeoutException|NoRouteToHostException|Read timed out'
        $attempts += [ordered]@{ number = $attempt + 1; exit_code = $exitCode; network_failure = [bool]$networkFailure; log = $attemptLog }
        if ($exitCode -eq 0 -or -not $networkFailure -or $attempt -eq $NetworkRetries) { break }
        Write-Output "Network transfer failed; retrying Maven (attempt $($attempt + 2)). First failure retained in $attemptLog"
    }
    if ($exitCode -ne 0) { throw "Maven exited with code $exitCode. Full log: $logFile" }
    if (-not $Offline -and -not $Platform) {
        & (Join-Path $PSScriptRoot 'Initialize-P2MetadataCache.ps1') -CacheRoot $CacheRoot
    }
    if ($exitCode -eq 0 -and $Goal -in @('package', 'verify')) {
        [xml]$project = Get-Content -LiteralPath (Join-Path $RepoRoot 'pom.xml') -Raw
        $artifact = & (Join-Path $PSScriptRoot 'Test-LegacyPackage.ps1') `
            -ArchivePath (Join-Path $RepoRoot "assembly/target/raox-$($project.project.version).zip") `
            -Version $project.project.version -ExpectedClassVersion $(if ($Platform) { 65 } else { 52 })
        $unitTests = [ordered]@{ tests = 0; failures = 0; errors = 0; skipped = 0 }
        Get-ChildItem -LiteralPath (Join-Path $RepoRoot 'ru.bmstu.rk9.rao.tests/target/surefire-reports') `
            -Filter 'TEST-*.xml' | ForEach-Object {
                [xml]$report = Get-Content -LiteralPath $_.FullName -Raw
                foreach ($key in @('tests', 'failures', 'errors', 'skipped')) {
                    $unitTests[$key] += [int]$report.testsuite.GetAttribute($key)
                }
            }
        $expectedTests = if ($Platform) { 38 } else { 32 }
        if ($unitTests.tests -ne $expectedTests -or $unitTests.failures -ne 0 -or $unitTests.errors -ne 0 -or $unitTests.skipped -ne 0) {
            throw "Expected $expectedTests passing JUnit checks with no skips; got $($unitTests | ConvertTo-Json -Compress)"
        }
        $dependencyVerification = & (Join-Path $PSScriptRoot 'Test-DependencyLocks.ps1') -CacheRoot $CacheRoot -LockRoot $lockRoot
    }
    $succeeded = $exitCode -eq 0
} catch {
    $failure = $_.Exception.Message
    throw
} finally {
    if ($locationPushed) { Pop-Location }
    $env:JAVA_HOME = $previousJavaHome
    $env:MAVEN_OPTS = $previousMavenOpts
    $env:MAVEN_USER_HOME = $previousMavenUserHome
    [ordered]@{
        started_at_utc = $startedAt.ToString('o')
        finished_at_utc = [DateTime]::UtcNow.ToString('o')
        goal = $Goal
        clean = [bool]$Clean
        offline = [bool]$Offline
        cache_initially_empty = $cacheInitiallyEmpty
        attempts = $attempts
        exit_code = $exitCode
        succeeded = $succeeded
        failure = $failure
        repository = $RepoRoot
        java_home = $javaDirectory
        maven = $mavenExecutable
        maven_repository = $repositoryDirectory
        target_platform_sha256 = (Get-FileHash -LiteralPath (Join-Path $RepoRoot 'raox.target/raox.target.target')).Hash.ToLowerInvariant()
        log = $logFile
        unit_tests = $unitTests
        dependency_verification = $dependencyVerification
        artifact = $artifact
    } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $resultFile -Encoding utf8
}
Get-Content -LiteralPath $logFile -Tail 45
if ($exitCode -ne 0) { throw "Maven exited with code $exitCode. Full log: $logFile" }
Write-Output "Maven succeeded. Full log: $logFile"
