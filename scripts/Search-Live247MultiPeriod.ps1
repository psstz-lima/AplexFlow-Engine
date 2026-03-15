param(
    [string]$BaseSetFile = (Join-Path $PSScriptRoot "..\mt5-portable\MQL5\Profiles\Tester\AplexFlow_Engine.robust_live_2526_retry.set")
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-FirstNumber {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return 0.0
    }

    $match = [regex]::Match($Value, '-?\d+(?:\.\d+)?')
    if (-not $match.Success) {
        return 0.0
    }

    return [double]::Parse($match.Value, [System.Globalization.CultureInfo]::InvariantCulture)
}

function Invoke-Period {
    param(
        [string]$RunName,
        [string]$FromDate,
        [string]$ToDate,
        [string[]]$Override
    )

    return (& (Join-Path $PSScriptRoot 'Run-Mt5Backtest.ps1') `
        -RunName $RunName `
        -BaseSetFile $BaseSetFile `
        -Override $Override `
        -Symbol 'XAUUSD' `
        -Period 'M5' `
        -FromDate $FromDate `
        -ToDate $ToDate `
        -Deposit 200 `
        -Model 4 `
        -ExecutionMode 200 | ConvertFrom-Json)
}

function Score-Case {
    param($Y2025, $Y2026, $Y2526)

    $net2025 = [double]$Y2025.total_net_profit
    $net2026 = [double]$Y2026.total_net_profit
    $net2526 = [double]$Y2526.total_net_profit
    $trades2526 = [double]$Y2526.total_trades
    $eqdd2526 = Get-FirstNumber $Y2526.equity_drawdown_raw
    $eqdd2025 = Get-FirstNumber $Y2025.equity_drawdown_raw
    $eqdd2026 = Get-FirstNumber $Y2026.equity_drawdown_raw

    $penalty = 0.0
    if ($net2025 -le 0.0) { $penalty += 200.0 }
    if ($net2026 -le 0.0) { $penalty += 200.0 }
    if ($net2526 -le 0.0) { $penalty += 400.0 }

    return (($net2526 * 8.0) + ($net2025 * 2.0) + ($net2026 * 2.0) + ($trades2526 * 0.20) - ($eqdd2526 * 4.0) - ($eqdd2025 * 2.0) - ($eqdd2026 * 1.0) - $penalty)
}

$cases = @(
    @{ Name = 'live247_mp_01_base'; Override = @() },
    @{ Name = 'live247_mp_02_ap8_resume105'; Override = @('InpAutoPauseHours=8','InpAutoPausePfResume=1.05') },
    @{ Name = 'live247_mp_03_ap12_resume105'; Override = @('InpAutoPauseHours=12','InpAutoPausePfResume=1.05') },
    @{ Name = 'live247_mp_04_ap8_resume102'; Override = @('InpAutoPauseHours=8','InpAutoPausePfResume=1.02') },
    @{ Name = 'live247_mp_05_no_ap'; Override = @('InpUseAutoPause=false') },
    @{ Name = 'live247_mp_06_rl12'; Override = @('InpRiskLadderWindowTrades=12','InpRiskLadderHighScale=1.60','InpRiskLadderMaxScale=1.60') },
    @{ Name = 'live247_mp_07_rl16'; Override = @('InpRiskLadderWindowTrades=16','InpRiskLadderHighScale=1.55','InpRiskLadderMaxScale=1.60') },
    @{ Name = 'live247_mp_08_ap8_rl12'; Override = @('InpAutoPauseHours=8','InpAutoPausePfResume=1.05','InpRiskLadderWindowTrades=12','InpRiskLadderHighScale=1.60','InpRiskLadderMaxScale=1.60') },
    @{ Name = 'live247_mp_09_ap8_rl12_disp70'; Override = @('InpAutoPauseHours=8','InpAutoPausePfResume=1.05','InpRiskLadderWindowTrades=12','InpRiskLadderHighScale=1.60','InpRiskLadderMaxScale=1.60','InpLqMinDisplacementAtr=0.70') },
    @{ Name = 'live247_mp_10_ap8_rl12_disp65_swing10'; Override = @('InpAutoPauseHours=8','InpAutoPausePfResume=1.05','InpRiskLadderWindowTrades=12','InpRiskLadderHighScale=1.60','InpRiskLadderMaxScale=1.60','InpLqMinDisplacementAtr=0.65','InpLqSwingLookback=10') },
    @{ Name = 'live247_mp_11_ap8_rl12_disp65_swing10_mss2'; Override = @('InpAutoPauseHours=8','InpAutoPausePfResume=1.05','InpRiskLadderWindowTrades=12','InpRiskLadderHighScale=1.60','InpRiskLadderMaxScale=1.60','InpLqMinDisplacementAtr=0.65','InpLqSwingLookback=10','InpLqMssLookback=2') },
    @{ Name = 'live247_mp_12_ap8_rl12_disp65_swing10_mss2_tp130'; Override = @('InpAutoPauseHours=8','InpAutoPausePfResume=1.05','InpRiskLadderWindowTrades=12','InpRiskLadderHighScale=1.60','InpRiskLadderMaxScale=1.60','InpLqMinDisplacementAtr=0.65','InpLqSwingLookback=10','InpLqMssLookback=2','InpLqTpR=1.30') }
)

$results = foreach ($case in $cases) {
    Write-Host ("Running {0}..." -f $case.Name)
    $overrides = @('Debug=0') + $case.Override
    $y2025 = Invoke-Period -RunName ($case.Name + '_2025') -FromDate '2025.01.02' -ToDate '2025.12.31' -Override $overrides
    $y2026 = Invoke-Period -RunName ($case.Name + '_2026') -FromDate '2026.01.01' -ToDate '2026.03.11' -Override $overrides
    $y2526 = Invoke-Period -RunName ($case.Name + '_2526') -FromDate '2025.01.02' -ToDate '2026.03.11' -Override $overrides

    [pscustomobject]@{
        run_name = $case.Name
        score = [math]::Round((Score-Case -Y2025 $y2025 -Y2026 $y2026 -Y2526 $y2526), 2)
        net_2025 = [double]$y2025.total_net_profit
        pf_2025 = [double]$y2025.profit_factor
        trades_2025 = [int]$y2025.total_trades
        eqdd_2025 = $y2025.equity_drawdown_raw
        net_2026 = [double]$y2026.total_net_profit
        pf_2026 = [double]$y2026.profit_factor
        trades_2026 = [int]$y2026.total_trades
        eqdd_2026 = $y2026.equity_drawdown_raw
        net_2526 = [double]$y2526.total_net_profit
        pf_2526 = [double]$y2526.profit_factor
        trades_2526 = [int]$y2526.total_trades
        eqdd_2526 = $y2526.equity_drawdown_raw
        overrides = $overrides
        report_2526 = $y2526.report_path
    }
}

$sorted = $results | Sort-Object @{ Expression = 'score'; Descending = $true }, @{ Expression = 'net_2526'; Descending = $true }, @{ Expression = 'net_2026'; Descending = $true }
$jsonPath = Join-Path $PSScriptRoot '..\mt5-portable\reports\live247_multi_period_search.json'
$txtPath = Join-Path $PSScriptRoot '..\mt5-portable\reports\live247_multi_period_search.txt'
$sorted | ConvertTo-Json -Depth 6 | Set-Content -Encoding ascii $jsonPath
$sorted | Format-Table run_name, score, net_2025, net_2026, net_2526, pf_2526, trades_2526, eqdd_2526 -AutoSize | Out-String | Set-Content -Encoding ascii $txtPath
Get-Content $txtPath
