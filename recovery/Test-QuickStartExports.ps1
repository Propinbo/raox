[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$RunRoot)
$ErrorActionPreference = 'Stop'
$csv = @(Import-Csv -LiteralPath (Join-Path $RunRoot 'docs-quickstart.csv'))
$json = @(Get-Content -LiteralPath (Join-Path $RunRoot 'docs-quickstart.json') -Raw -Encoding utf8 | ConvertFrom-Json)
if ($csv.Count -ne 5 -or $json.Count -ne 5) { throw 'Quick start must export five points.' }
$culture = [Globalization.CultureInfo]::InvariantCulture
for ($i = 0; $i -lt 5; $i++) {
    $x = [double]::Parse($csv[$i].x, $culture)
    $y = [double]::Parse($csv[$i].y, $culture)
    if ($x -ne [Math]::Max(0, $i - 1) -or $y -ne $i -or $x -ne [double]$json[$i].x -or $y -ne [double]$json[$i].y) {
        throw "Quick start point $i differs from the documented model or JSON."
    }
}
$trace = Get-Content -LiteralPath (Join-Path $RunRoot 'docs-quickstart.trc') -Raw -Encoding utf8
$result = Get-Content -LiteralPath (Join-Path $RunRoot 'docs-quickstart.res') -Raw -Encoding utf8
if ($result.Replace("`r`n", "`n").Trim() -ne "hello.hello.total`n  Last value: 4") {
    throw 'Quick start result differs from the guide.'
}
if ([regex]::Matches($trace, '(?m)^EI ').Count -ne 4 -or $trace -notmatch 'ES 3\.0 Simulation finished: terminate condition') {
    throw 'Expected exactly four events and stop at model time 3.'
}
[ordered]@{ points = 5; csv_json_equal = $true; samples_match_guide = $true;
    events = 4; trace_stop_time = 3.0; last_value = 4 } |
    ConvertTo-Json | Set-Content -LiteralPath (Join-Path $RunRoot 'quickstart-validation.json') -Encoding utf8
Get-Content -LiteralPath (Join-Path $RunRoot 'quickstart-validation.json')
