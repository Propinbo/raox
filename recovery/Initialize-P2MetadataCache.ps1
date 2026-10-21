[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$CacheRoot,
    [switch]$Offline
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$metadataRoot = Join-Path $CacheRoot '.cache/tycho/p2-repository-metadata'
$null = New-Item -ItemType Directory -Path $metadataRoot -Force
$entries = @(Get-Content -LiteralPath (Join-Path $PSScriptRoot 'p2-metadata.lock.json') -Raw | ConvertFrom-Json)
# Tycho 0.23 caches XZ metadata by the remote file URI, but its offline fallback
# only searches content/artifacts + repository URI.hashCode() + .jar/.xml.
# cache_file contains that Java URI hash for each fixed release repository.
foreach ($entry in $entries) {
    $file = Join-Path $metadataRoot $entry.cache_file
    if ((Test-Path -LiteralPath $file) -and
        (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash -eq $entry.sha256) { continue }
    if ($Offline) { throw "Missing or changed offline p2 metadata: $($entry.cache_file). Run an online build first." }
    $temporary = "$file.download"
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        try {
            Invoke-WebRequest -Uri $entry.url -OutFile $temporary -UseBasicParsing -TimeoutSec 60
            break
        } catch {
            if ($attempt -eq 3) { throw }
            Write-Output "p2 metadata download attempt $attempt failed; retrying $($entry.cache_file)."
        }
    }
    if ((Get-FileHash -LiteralPath $temporary -Algorithm SHA256).Hash -ne $entry.sha256) {
        throw "p2 metadata SHA-256 mismatch: $($entry.url)"
    }
    Move-Item -LiteralPath $temporary -Destination $file -Force
}
Write-Output "Verified $($entries.Count) pinned p2 metadata files for offline use."
