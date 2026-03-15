param(
    [string]$RunName = "bt_run",
    [string]$PortableRoot = (Join-Path $PSScriptRoot "..\\mt5-portable"),
    [string]$BaseSetFile = (Join-Path $PSScriptRoot "..\\mt5-portable\\MQL5\\Profiles\\Tester\\AplexFlow_Engine.set"),
    [string[]]$Override = @(),
    [string]$Symbol = "XAUUSD",
    [string]$Period = "M5",
    [string]$FromDate = "2026.01.01",
    [string]$ToDate = "2026.03.11",
    [int]$Deposit = 200,
    [int]$Model = 4,
    [int]$ExecutionMode = 200,
    [string]$Currency = "USD",
    [string]$Leverage = "1:100"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Set-SetValue {
    param(
        [string[]]$Lines,
        [string]$Key,
        [string]$Value
    )

    $found = $false
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -match "^(?<name>[^=]+)=(?<current>[^|]*)(?<rest>.*)$" -and $matches.name -eq $Key) {
            $Lines[$i] = "{0}={1}{2}" -f $Key, $Value, $matches.rest
            $found = $true
            break
        }
    }

    if (-not $found) {
        $Lines += "{0}={1}" -f $Key, $Value
    }

    return ,$Lines
}

function Parse-Override {
    param([string]$Item)

    $parts = $Item -split "=", 2
    if ($parts.Count -ne 2) {
        throw "Override invalido: '$Item'. Use o formato Chave=Valor."
    }

    return @{
        Key = $parts[0].Trim()
        Value = $parts[1].Trim()
    }
}

function Get-ReportPairs {
    param([string]$ReportPath)

    $raw = Get-Content -Path $ReportPath -Raw -Encoding Default
    $pairs = [ordered]@{}
    $regex = [regex]::new(
        "<td[^>]*>\s*(?<label>[^<]+?)\s*</td>\s*<td[^>]*>\s*<b>(?<value>.*?)</b>\s*</td>",
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor
        [System.Text.RegularExpressions.RegexOptions]::Singleline
    )

    foreach ($match in $regex.Matches($raw)) {
        $label = Normalize-Label ([System.Net.WebUtility]::HtmlDecode($match.Groups["label"].Value).Trim())
        $value = [System.Net.WebUtility]::HtmlDecode($match.Groups["value"].Value).Trim()
        if ([string]::IsNullOrWhiteSpace($label)) {
            continue
        }

        if ($pairs.Contains($label)) {
            continue
        }

        $pairs[$label] = $value
    }

    return $pairs
}

function Normalize-Label {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ""
    }

    $normalized = $Value.Normalize([Text.NormalizationForm]::FormD)
    $builder = [System.Text.StringBuilder]::new()
    foreach ($char in $normalized.ToCharArray()) {
        $category = [Globalization.CharUnicodeInfo]::GetUnicodeCategory($char)
        if ($category -ne [Globalization.UnicodeCategory]::NonSpacingMark) {
            $null = $builder.Append($char)
        }
    }

    return ([regex]::Replace($builder.ToString(), "\s+", " ")).Trim()
}

function Get-FirstNumber {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }

    $match = [regex]::Match($Value, "-?\d+(?:\.\d+)?")
    if (-not $match.Success) {
        return $null
    }

    return [double]::Parse($match.Value, [System.Globalization.CultureInfo]::InvariantCulture)
}

$portableRootResolved = (Resolve-Path $PortableRoot).Path
$baseSetResolved = (Resolve-Path $BaseSetFile).Path
$terminalPath = Join-Path $portableRootResolved "terminal64.exe"
$profilesDir = Join-Path $portableRootResolved "MQL5\\Profiles\\Tester"
$reportsDir = Join-Path $portableRootResolved "reports"
$reportBase = "reports\\$RunName"
$reportPath = Join-Path $reportsDir "$RunName.htm"
$setName = "AplexFlow_Engine.$RunName.set"
$setPath = Join-Path $profilesDir $setName
$iniPath = Join-Path $portableRootResolved "tester.$RunName.ini"

if (-not (Test-Path $terminalPath)) {
    throw "Nao encontrei o terminal em '$terminalPath'."
}

$lines = [System.Collections.Generic.List[string]]::new()
foreach ($line in [System.IO.File]::ReadAllLines($baseSetResolved)) {
    $null = $lines.Add($line)
}

foreach ($item in $Override) {
    $parsed = Parse-Override -Item $item
    $updated = Set-SetValue -Lines $lines.ToArray() -Key $parsed.Key -Value $parsed.Value
    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($line in $updated) {
        $null = $lines.Add($line)
    }
}

[System.IO.File]::WriteAllLines($setPath, $lines, [System.Text.Encoding]::ASCII)

$iniContent = @"
[Tester]
Expert=AplexFlow\AplexFlow_Engine.ex5
ExpertParameters=$setName
Symbol=$Symbol
Period=$Period
Model=$Model
ExecutionMode=$ExecutionMode
Optimization=0
OptimizationCriterion=6
FromDate=$FromDate
ToDate=$ToDate
ForwardMode=0
Deposit=$Deposit
Currency=$Currency
Leverage=$Leverage
Report=$reportBase
ReplaceReport=1
ShutdownTerminal=1
Visual=0
"@

[System.IO.File]::WriteAllText($iniPath, $iniContent, [System.Text.Encoding]::ASCII)

if (Test-Path $reportPath) {
    Remove-Item -Path $reportPath -Force
}

$process = Start-Process -FilePath $terminalPath `
    -ArgumentList "/portable", "/config:$iniPath" `
    -WorkingDirectory $portableRootResolved `
    -Wait `
    -PassThru

if ($process.ExitCode -ne 0) {
    throw "O terminal retornou exit code $($process.ExitCode)."
}

if (-not (Test-Path $reportPath)) {
    throw "O relatorio nao foi gerado em '$reportPath'."
}

$pairs = Get-ReportPairs -ReportPath $reportPath

$result = [ordered]@{
    run_name = $RunName
    report_path = $reportPath
    set_path = $setPath
    exit_code = $process.ExitCode
    symbol = $Symbol
    period = $Period
    from = $FromDate
    to = $ToDate
    deposit = $Deposit
    model = $Model
    execution_mode = $ExecutionMode
    overrides = $Override
    total_net_profit = Get-FirstNumber $pairs["Lucro Liquido Total:"]
    profit_factor = Get-FirstNumber $pairs["Fator de Lucro:"]
    expected_payoff = Get-FirstNumber $pairs["Retorno Esperado (Payoff):"]
    total_trades = [int](Get-FirstNumber $pairs["Total de Negociacoes:"])
    winning_trades_raw = $pairs["Negociacoes com Lucro (% of total):"]
    losing_trades_raw = $pairs["Negociacoes com Perda (% of total):"]
    balance_drawdown_raw = $pairs["Rebaixamento Maximo do Saldo :"]
    equity_drawdown_raw = $pairs["Rebaixamento Maximo do Capital Liquido:"]
    history_quality = $pairs["Qualidade do historico:"]
    final_balance = (Get-FirstNumber $pairs["Deposito Inicial:"]) + (Get-FirstNumber $pairs["Lucro Liquido Total:"])
}

$result | ConvertTo-Json -Depth 4
