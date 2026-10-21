[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$CacheRoot,
    [string]$LockRoot = (Join-Path $PSScriptRoot 'platform')
)
$ErrorActionPreference = 'Stop'
$CacheRoot = (Resolve-Path -LiteralPath $CacheRoot).Path
$null = New-Item -ItemType Directory -Path $LockRoot -Force
$bundles = @(Get-ChildItem -LiteralPath (Join-Path $CacheRoot 'p2/osgi/bundle') -Recurse -File -Filter '*.jar' |
    Sort-Object FullName | ForEach-Object {
        [ordered]@{
            id = $_.Directory.Parent.Name
            version = $_.Directory.Name
            sha256 = (Get-FileHash -LiteralPath $_.FullName).Hash.ToLowerInvariant()
            content_sha256 = & (Join-Path $PSScriptRoot 'Get-JarContentHash.ps1') -Path $_.FullName
        }
    })
if ($bundles.Count -eq 0) { throw 'No resolved p2 bundles found.' }
[ordered]@{ platform = 'win32/win32/x86_64'; bundles = $bundles } | ConvertTo-Json -Depth 5 |
    Set-Content -LiteralPath (Join-Path $LockRoot 'p2-bundles.lock.json') -Encoding utf8
Get-ChildItem -LiteralPath $CacheRoot -Recurse -File | Where-Object {
    $relative = $_.FullName.Substring($CacheRoot.Length + 1).Replace('\', '/')
    $relative -notmatch '^(p2|\.cache|\.meta|\.wrapper)/' -and $_.Extension -in @('.jar', '.zip')
} | Sort-Object FullName | ForEach-Object {
    [pscustomobject]@{
        path = $_.FullName.Substring($CacheRoot.Length + 1).Replace('\', '/')
        sha256 = (Get-FileHash -LiteralPath $_.FullName).Hash.ToLowerInvariant()
    }
} | Export-Csv -LiteralPath (Join-Path $LockRoot 'maven-artifacts.lock.csv') -NoTypeInformation -Encoding utf8
Write-Output "Exported $($bundles.Count) p2 bundles and the Maven binary inventory to $LockRoot"
Get-ChildItem -LiteralPath (Join-Path $CacheRoot 'p2') -Recurse -File -Filter '*.jar' |
    Where-Object { $_.FullName -notmatch '[\\/]p2[\\/]osgi[\\/]bundle[\\/]' } |
    Sort-Object FullName | ForEach-Object {
        [pscustomobject]@{
            path = $_.FullName.Substring($CacheRoot.Length + 1).Replace('\','/')
            sha256 = (Get-FileHash -LiteralPath $_.FullName).Hash.ToLowerInvariant()
            content_sha256 = & (Join-Path $PSScriptRoot 'Get-JarContentHash.ps1') -Path $_.FullName
        }
    } | Export-Csv -LiteralPath (Join-Path $LockRoot 'p2-extra-artifacts.lock.csv') -NoTypeInformation -Encoding utf8
