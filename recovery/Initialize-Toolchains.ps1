[CmdletBinding()]
param(
    [string]$ToolchainRoot = (Join-Path (Split-Path -Parent $PSScriptRoot) '.build/tools'),
    [switch]$IncludeUi,
    [string]$LockFile = (Join-Path $PSScriptRoot 'toolchains.lock.json')
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$lock = Get-Content -LiteralPath $LockFile -Raw | ConvertFrom-Json
$null = New-Item -ItemType Directory -Path $ToolchainRoot -Force
$ToolchainRoot = (Resolve-Path -LiteralPath $ToolchainRoot).Path
$names = @('jdk')
if ($IncludeUi) { $names += @('eclipse', 'rcptt') }
foreach ($name in $names) {
    $tool = $lock.$name
    $destination = if ($name -eq 'jdk') { $ToolchainRoot } else { Join-Path $ToolchainRoot $name }
    $probe = Join-Path (Join-Path $destination $tool.directory) $tool.probe
    $receipt = Join-Path $destination "$name.sha256"
    if ((Test-Path -LiteralPath $probe) -and (Test-Path -LiteralPath $receipt) -and
        (Get-Content -LiteralPath $receipt -Raw).Trim() -eq $tool.sha256) {
        Write-Output "Verified installation already available: $name ($($tool.version))"
        continue
    }
    $archive = Join-Path $ToolchainRoot "$name.zip"
    if (-not (Test-Path -LiteralPath $archive) -or
        (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne $tool.sha256) {
        Write-Output "Downloading $name ($($tool.version))"
        for ($attempt = 1; $attempt -le 3; $attempt++) {
            try {
                Invoke-WebRequest -Uri $tool.url -OutFile $archive -UseBasicParsing -TimeoutSec 120
                break
            } catch {
                if ($attempt -eq 3) { throw }
                Write-Output "Download attempt $attempt failed for $name; retrying."
            }
        }
    }
    if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne $tool.sha256) {
        throw "SHA-256 mismatch: $archive"
    }
    $null = New-Item -ItemType Directory -Path $destination -Force
    Expand-Archive -LiteralPath $archive -DestinationPath $destination -Force
    if (-not (Test-Path -LiteralPath $probe)) { throw "Archive does not contain $probe" }
    $tool.sha256 | Set-Content -LiteralPath $receipt -Encoding ascii
    Write-Output "Installed and verified: $name ($($tool.version))"
}
