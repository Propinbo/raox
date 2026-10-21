[CmdletBinding()]
param(
    [string]$ToolchainRoot = (Join-Path (Split-Path -Parent $PSScriptRoot) '.build/platform-tools'),
    [switch]$IncludeUi
)
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'Initialize-Toolchains.ps1') -ToolchainRoot $ToolchainRoot `
    -LockFile (Join-Path $PSScriptRoot 'platform/toolchains.lock.json') -IncludeUi:$IncludeUi
