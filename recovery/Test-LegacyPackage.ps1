[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ArchivePath,
    [string]$Version = '3.9.0',
    [int]$ExpectedClassVersion = 0
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
    $classesChecked = 0
    if ($ExpectedClassVersion -gt 0) {
        foreach ($name in $expected | Where-Object { $_ -ne 'raox/ru.bmstu.rk9.rao.lib.jar' }) {
            $jarStream = $archive.GetEntry($name).Open()
            $jar = [IO.Compression.ZipArchive]::new($jarStream, [IO.Compression.ZipArchiveMode]::Read)
            try {
                foreach ($entry in $jar.Entries | Where-Object { $_.FullName.EndsWith('.class') }) {
                    $stream = $entry.Open()
                    $header = New-Object byte[] 8
                    try {
                        $offset = 0
                        while ($offset -lt 8) {
                            $read = $stream.Read($header, $offset, 8 - $offset)
                            if ($read -eq 0) { throw "Truncated class: $name/$($entry.FullName)" }
                            $offset += $read
                        }
                    } finally { $stream.Dispose() }
                    $major = 256 * [int]$header[6] + [int]$header[7]
                    if ($major -ne $ExpectedClassVersion) {
                        throw "Unexpected class version $major in $name/$($entry.FullName); expected $ExpectedClassVersion"
                    }
                    $classesChecked++
                }
            } finally {
                $jar.Dispose()
                $jarStream.Dispose()
            }
        }
        if ($classesChecked -eq 0) { throw 'Archive contains no compiled classes.' }
    }
    [pscustomobject]@{
        archive = $ArchivePath
        sha256 = (Get-FileHash -LiteralPath $ArchivePath -Algorithm SHA256).Hash.ToLowerInvariant()
        runtime_copy_identical = $true
        class_version = $ExpectedClassVersion
        classes_checked = $classesChecked
        entries = @($entries)
    }
} finally {
    $archive.Dispose()
}
