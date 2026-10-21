[CmdletBinding()]
param(
    [string]$ToolchainRoot = (Join-Path (Split-Path -Parent $PSScriptRoot) '.build/platform-tools'),
    [string]$CacheRoot = (Join-Path (Split-Path -Parent $PSScriptRoot) '.build/platform-m2'),
    [ValidateSet('validate', 'package', 'verify')][string]$Goal = 'verify',
    [switch]$Clean,
    [switch]$RequireEmptyCache,
    [switch]$Offline,
    [ValidateRange(0, 5)][int]$NetworkRetries = 3,
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$LogRoot = (Join-Path (Split-Path -Parent $PSScriptRoot) '.build/platform-evidence')
)
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'Invoke-LegacyBuild.ps1') -Platform -ToolchainRoot $ToolchainRoot `
    -CacheRoot $CacheRoot -Goal $Goal -Clean:$Clean -RequireEmptyCache:$RequireEmptyCache `
    -Offline:$Offline -NetworkRetries $NetworkRetries -RepoRoot $RepoRoot -LogRoot $LogRoot
