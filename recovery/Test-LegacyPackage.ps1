[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ArchivePath,
    [string]$Version = '3.9.0'
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$ArchivePath = (Resolve-Path -LiteralPath $ArchivePath).Path
$expected = @(
    "raox/ru.bmstu.rk9.rao-$Version.jar",
    "raox/ru.bmstu.rk9.rao.lib-$Version.jar",
    "raox/ru.bmstu.rk9.rao.ui-$Version.jar",
    "raox/ru.bmstu.rk9.raox.plugins.game5-$Version.jar",
    'raox/ru.bmstu.rk9.rao.lib.jar'
)
$archive = [IO.Compression.ZipFile]::OpenRead($ArchivePath)
try {
    $actual = @($archive.Entries | Where-Object { -not $_.FullName.EndsWith('/') } |
        ForEach-Object { $_.FullName })
    if (@(Compare-Object $expected $actual).Count -ne 0) {
        throw "Unexpected archive contents: $($actual -join ', ')"
    }
    $entries = foreach ($name in $expected) {
        $entry = $archive.GetEntry($name)
        $stream = $entry.Open()
        $sha = [Security.Cryptography.SHA256]::Create()
        try {
            $hash = [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-', '').ToLowerInvariant()
        } finally {
            $sha.Dispose()
            $stream.Dispose()
        }
        [pscustomobject]@{ name = $name; bytes = $entry.Length; sha256 = $hash }
    }
    $runtime = $entries | Where-Object name -eq "raox/ru.bmstu.rk9.rao.lib-$Version.jar"
    $runtimeCopy = $entries | Where-Object name -eq 'raox/ru.bmstu.rk9.rao.lib.jar'
    if ($runtime.sha256 -ne $runtimeCopy.sha256) { throw 'Unversioned runtime differs from the built runtime.' }
    [pscustomobject]@{
        archive = $ArchivePath
        sha256 = (Get-FileHash -LiteralPath $ArchivePath -Algorithm SHA256).Hash.ToLowerInvariant()
        runtime_copy_identical = $true
        entries = @($entries)
    }
} finally {
    $archive.Dispose()
}
