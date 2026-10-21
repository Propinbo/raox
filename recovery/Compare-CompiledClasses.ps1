[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ReferencePlugins,
    [Parameter(Mandatory = $true)][string]$CandidatePlugins
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
function Get-Classes([string]$Root) {
    $classes = @{}
    $jars = @(Get-ChildItem -LiteralPath $Root -File -Filter '*-3.9.0.jar')
    if ($jars.Count -ne 4) { throw "Expected four versioned plugins in $Root" }
    foreach ($file in $jars) {
        $jar = [IO.Compression.ZipFile]::OpenRead($file.FullName)
        try {
            foreach ($entry in $jar.Entries | Where-Object { $_.FullName.EndsWith('.class') }) {
                $stream = $entry.Open()
                $sha = [Security.Cryptography.SHA256]::Create()
                try {
                    $classes[$file.Name + '/' + $entry.FullName] = [BitConverter]::ToString($sha.ComputeHash($stream))
                } finally {
                    $stream.Dispose()
                    $sha.Dispose()
                }
            }
        } finally { $jar.Dispose() }
    }
    return $classes
}
$reference = Get-Classes $ReferencePlugins
$candidate = Get-Classes $CandidatePlugins
$differences = @(@($reference.Keys) + @($candidate.Keys) | Sort-Object -Unique | Where-Object {
    -not $reference.ContainsKey($_) -or -not $candidate.ContainsKey($_) -or $reference[$_] -ne $candidate[$_]
})
[ordered]@{
    reference_classes = $reference.Count
    candidate_classes = $candidate.Count
    identical = $differences.Count -eq 0
    differences = $differences
} | ConvertTo-Json -Depth 3
if ($differences.Count -gt 0) { throw "Compiled classes differ: $($differences.Count)" }
