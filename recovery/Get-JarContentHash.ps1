[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$Path)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $Path).Path)
$sha = [Security.Cryptography.SHA256]::Create()
try {
    $names = @($archive.Entries | Where-Object { -not $_.FullName.EndsWith('/') } | ForEach-Object FullName)
    [Array]::Sort($names, [StringComparer]::Ordinal)
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($name in $names) {
        if (-not $seen.Add($name) -or $name.Contains([char]0)) { throw "Invalid duplicate/NUL JAR entry: $name" }
        $stream = $archive.GetEntry($name).Open()
        $entrySha = [Security.Cryptography.SHA256]::Create()
        try {
            $entryHash = [BitConverter]::ToString($entrySha.ComputeHash($stream)).Replace('-', '').ToLowerInvariant()
        } finally {
            $stream.Dispose()
            $entrySha.Dispose()
        }
        # Hash sorted UTF-8 (entry name + NUL + SHA-256 of its complete bytes + LF).
        # ZIP timestamps, compression, extra fields and record order are not payload.
        $record = [Text.Encoding]::UTF8.GetBytes($name + [char]0 + $entryHash + "`n")
        $null = $sha.TransformBlock($record, 0, $record.Length, $record, 0)
    }
    $null = $sha.TransformFinalBlock([byte[]]@(), 0, 0)
    [BitConverter]::ToString($sha.Hash).Replace('-', '').ToLowerInvariant()
} finally {
    $sha.Dispose()
    $archive.Dispose()
}
