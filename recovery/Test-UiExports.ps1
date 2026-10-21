[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$RunRoot)
$ErrorActionPreference = 'Stop'
$csv = @(Import-Csv -LiteralPath (Join-Path $RunRoot 'ui-exports.csv'))
$json = @(Get-Content -LiteralPath (Join-Path $RunRoot 'ui-exports.json') -Raw | ConvertFrom-Json)
if ($csv.Count -ne 5 -or $json.Count -ne $csv.Count) { throw 'Expected five exported samples in both formats.' }
$culture = [Globalization.CultureInfo]::InvariantCulture
for ($i = 0; $i -lt $csv.Count; $i++) {
    $x = [double]::Parse($csv[$i].x, $culture)
    $y = [double]::Parse($csv[$i].y, $culture)
    if ($x -ne [double]$json[$i].x -or $y -ne [double]$json[$i].y) {
        throw "CSV and JSON differ at sample $i."
    }
    $expectedTime = [Math]::Max(0, $i - 1)
    if ($x -ne $expectedTime -or $y -ne $i) { throw "Unexpected model sample $i : ($x, $y)." }
}
$trace = Get-Content -LiteralPath (Join-Path $RunRoot 'ui-exports.trc') -Raw
if ($trace -notmatch 'ES 3\.0 Simulation finished: terminate condition') { throw 'Exported trace has an unexpected stop.' }
[ordered]@{ points = $csv.Count; csv_json_equal = $true; samples_match_model = $true; trace_stop_time = 3.0 } |
    ConvertTo-Json | Set-Content -LiteralPath (Join-Path $RunRoot 'export-validation.json') -Encoding utf8
Get-Content -LiteralPath (Join-Path $RunRoot 'export-validation.json')
