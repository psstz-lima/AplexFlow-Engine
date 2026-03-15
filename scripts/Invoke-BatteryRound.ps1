param(
    [ValidateSet("Adaptive", "Liquidity")]
    [string]$Mode = "Adaptive",
    [int[]]$SwingLookback = @(12),
    [int[]]$FiboMaxBars = @(4, 8, 12),
    [double[]]$FiboTolAtr = @(0.10, 0.15, 0.20),
    [int[]]$AdaptMinBarsBetweenChanges = @(2, 6),
    [int[]]$AdaptConfirmBars = @(1, 2),
    [string]$OutputPath = (Join-Path $PSScriptRoot "..\\mt5-portable\\reports\\battery_round.json")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function To-InvariantString {
    param([double]$Value)
    return $Value.ToString([System.Globalization.CultureInfo]::InvariantCulture)
}

function To-RunToken {
    param([double]$Value)
    return (To-InvariantString $Value).Replace(".", "p")
}

$runScript = Join-Path $PSScriptRoot "Run-Mt5Backtest.ps1"
if (-not (Test-Path $runScript)) {
    throw "Nao encontrei o runner em '$runScript'."
}

$results = [System.Collections.Generic.List[object]]::new()
$modeValue = if ($Mode -eq "Liquidity") { 1 } else { 0 }

if ($Mode -eq "Adaptive") {
    foreach ($lookback in $SwingLookback) {
        foreach ($maxBars in $FiboMaxBars) {
            foreach ($tol in $FiboTolAtr) {
                foreach ($minBars in $AdaptMinBarsBetweenChanges) {
                    foreach ($confirm in $AdaptConfirmBars) {
                        $runName = "bat_ad_lb{0}_mb{1}_tol{2}_min{3}_cf{4}" -f $lookback, $maxBars, (To-RunToken $tol), $minBars, $confirm
                        $overrides = @(
                            "InpTradingMode=$modeValue",
                            "InpConfigTemplate=2",
                            "InpSwingLookback=$lookback",
                            "InpFiboMaxBarsToTrigger=$maxBars",
                            ("InpFiboTolAtr=" + (To-InvariantString $tol)),
                            "InpAdaptMinBarsBetweenChanges=$minBars",
                            "InpAdaptConfirmBars=$confirm"
                        )

                        $result = & $runScript -RunName $runName -Override $overrides | ConvertFrom-Json
                        $null = $results.Add($result)

                        Write-Host ("{0} => net={1} pf={2} trades={3}" -f `
                            $result.run_name, `
                            $result.total_net_profit, `
                            $result.profit_factor, `
                            $result.total_trades)
                    }
                }
            }
        }
    }
}
else {
    $runName = "bat_liq_baseline"
    $overrides = @(
        "InpTradingMode=$modeValue",
        "InpConfigTemplate=2"
    )

    $result = & $runScript -RunName $runName -Override $overrides | ConvertFrom-Json
    $null = $results.Add($result)
    Write-Host ("{0} => net={1} pf={2} trades={3}" -f `
        $result.run_name, `
        $result.total_net_profit, `
        $result.profit_factor, `
        $result.total_trades)
}

$sorted = $results | Sort-Object total_net_profit -Descending
$outputDir = Split-Path -Path $OutputPath -Parent
if (-not (Test-Path $outputDir)) {
    New-Item -Path $outputDir -ItemType Directory | Out-Null
}

$sorted | ConvertTo-Json -Depth 4 | Set-Content -Path $OutputPath -Encoding UTF8
$sorted | Select-Object -First 10 run_name,total_net_profit,profit_factor,total_trades,balance_drawdown_raw,equity_drawdown_raw | Format-Table -AutoSize
Write-Host ("Saved=" + $OutputPath)
