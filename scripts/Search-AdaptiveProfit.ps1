param(
    [int[]]$SwingLookback = @(10),
    [int[]]$FiboMaxBarsToTrigger = @(3),
    [double[]]$FiboTolAtr = @(0.10),
    [int[]]$AdaptConfirmBars = @(2, 3),
    [int[]]$AdaptMinBarsBetweenChanges = @(2, 4),
    [double[]]$MinTrendStrengthAtr = @(0.030, 0.035),
    [double[]]$BreakoutBodyAtrMin = @(0.09, 0.11, 0.13),
    [double[]]$BreakoutCloseStrengthMin = @(0.49, 0.53),
    [int[]]$Lookback = @(8),
    [string]$OutputPath = (Join-Path $PSScriptRoot "..\\mt5-portable\\reports\\adaptive_profit_search.json")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function To-InvariantString {
    param([double]$Value)
    return $Value.ToString([System.Globalization.CultureInfo]::InvariantCulture)
}

function To-Token {
    param([double]$Value)
    return (To-InvariantString $Value).Replace(".", "p")
}

$runScript = Join-Path $PSScriptRoot "Run-Mt5Backtest.ps1"
if (-not (Test-Path $runScript)) {
    throw "Nao encontrei o runner em '$runScript'."
}

$results = [System.Collections.Generic.List[object]]::new()
$totalRuns = $SwingLookback.Count *
             $FiboMaxBarsToTrigger.Count *
             $FiboTolAtr.Count *
             $AdaptConfirmBars.Count *
             $AdaptMinBarsBetweenChanges.Count *
             $MinTrendStrengthAtr.Count *
             $BreakoutBodyAtrMin.Count *
             $BreakoutCloseStrengthMin.Count *
             $Lookback.Count

$runIndex = 0

foreach ($swing in $SwingLookback) {
    foreach ($fiboBars in $FiboMaxBarsToTrigger) {
        foreach ($fiboTol in $FiboTolAtr) {
            foreach ($confirm in $AdaptConfirmBars) {
                foreach ($minBars in $AdaptMinBarsBetweenChanges) {
                    foreach ($trend in $MinTrendStrengthAtr) {
                        foreach ($body in $BreakoutBodyAtrMin) {
                            foreach ($close in $BreakoutCloseStrengthMin) {
                                foreach ($coreLookback in $Lookback) {
                                    $runIndex++
                                    $runName = "adp_s{0}_fb{1}_ft{2}_cf{3}_mb{4}_tr{5}_bd{6}_cl{7}_lb{8}" -f `
                                        $swing, `
                                        $fiboBars, `
                                        (To-Token $fiboTol), `
                                        $confirm, `
                                        $minBars, `
                                        (To-Token $trend), `
                                        (To-Token $body), `
                                        (To-Token $close), `
                                        $coreLookback

                                    $overrides = @(
                                        "InpTradingMode=0",
                                        "InpConfigTemplate=2",
                                        "InpSwingLookback=$swing",
                                        "InpFiboMaxBarsToTrigger=$fiboBars",
                                        ("InpFiboTolAtr=" + (To-InvariantString $fiboTol)),
                                        "InpAdaptConfirmBars=$confirm",
                                        "InpAdaptMinBarsBetweenChanges=$minBars",
                                        ("InpMinTrendStrengthAtr=" + (To-InvariantString $trend)),
                                        ("InpBreakoutBodyAtrMin=" + (To-InvariantString $body)),
                                        ("InpBreakoutCloseStrengthMin=" + (To-InvariantString $close)),
                                        "InpLookback=$coreLookback"
                                    )

                                    $result = & $runScript -RunName $runName -Override $overrides | ConvertFrom-Json
                                    $null = $result | Add-Member -NotePropertyName swing_lookback -NotePropertyValue $swing -PassThru |
                                        Add-Member -NotePropertyName fibo_max_bars -NotePropertyValue $fiboBars -PassThru |
                                        Add-Member -NotePropertyName fibo_tol_atr -NotePropertyValue $fiboTol -PassThru |
                                        Add-Member -NotePropertyName adapt_confirm_bars -NotePropertyValue $confirm -PassThru |
                                        Add-Member -NotePropertyName adapt_min_bars_between_changes -NotePropertyValue $minBars -PassThru |
                                        Add-Member -NotePropertyName min_trend_strength_atr -NotePropertyValue $trend -PassThru |
                                        Add-Member -NotePropertyName breakout_body_atr_min -NotePropertyValue $body -PassThru |
                                        Add-Member -NotePropertyName breakout_close_strength_min -NotePropertyValue $close -PassThru |
                                        Add-Member -NotePropertyName lookback -NotePropertyValue $coreLookback -PassThru
                                    $null = $results.Add($result)

                                    Write-Host ("[{0}/{1}] {2} => net={3} pf={4} trades={5}" -f `
                                        $runIndex, `
                                        $totalRuns, `
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
        }
    }
}

$sorted = $results | Sort-Object total_net_profit -Descending
$outputDir = Split-Path -Path $OutputPath -Parent
if (-not (Test-Path $outputDir)) {
    New-Item -Path $outputDir -ItemType Directory | Out-Null
}

$sorted | ConvertTo-Json -Depth 5 | Set-Content -Path $OutputPath -Encoding UTF8
$sorted | Select-Object -First 15 run_name,total_net_profit,profit_factor,total_trades,balance_drawdown_raw,equity_drawdown_raw,min_trend_strength_atr,breakout_body_atr_min,breakout_close_strength_min,adapt_confirm_bars,adapt_min_bars_between_changes | Format-Table -AutoSize
Write-Host ("Saved=" + $OutputPath)
