param(
    [string]$BaseSetFile = (Join-Path $PSScriptRoot "..\..\mt5-portable\MQL5\Profiles\Tester\AplexFlow_Engine.robust_live_2526_retry.set")
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

    return (& (Join-Path $PSScriptRoot '..\\Run-Mt5Backtest.ps1') `
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

    $penalty = 0.0
    if ($net2025 -le 0.0) { $penalty += 300.0 }
    if ($net2026 -le 0.0) { $penalty += 150.0 }
    if ($net2526 -le 0.0) { $penalty += 500.0 }

    return (($net2526 * 12.0) + ($net2025 * 3.0) + ($net2026 * 2.0) + ($trades2526 * 0.20) - ($eqdd2526 * 3.0) - $penalty)
}

$winnerBase = @(
    'Debug=0',
    'InpUseAutoPause=false',
    'InpUseBreakEven=false',
    'InpTrailStartAtr=1.20',
    'InpTrailAtrMult=1.00'
)

$cases = @(
    @{ Name = 'live247_win_01_base'; Override = @() },
    @{ Name = 'live247_win_02_ts110_td100'; Override = @('InpTrailStartAtr=1.10','InpTrailAtrMult=1.00') },
    @{ Name = 'live247_win_03_ts130_td100'; Override = @('InpTrailStartAtr=1.30','InpTrailAtrMult=1.00') },
    @{ Name = 'live247_win_04_ts120_td090'; Override = @('InpTrailStartAtr=1.20','InpTrailAtrMult=0.90') },
    @{ Name = 'live247_win_05_ts120_td110'; Override = @('InpTrailStartAtr=1.20','InpTrailAtrMult=1.10') },
    @{ Name = 'live247_win_06_ts130_td110'; Override = @('InpTrailStartAtr=1.30','InpTrailAtrMult=1.10') },
    @{ Name = 'live247_win_07_tp128'; Override = @('InpLqTpR=1.28') },
    @{ Name = 'live247_win_08_tp130'; Override = @('InpLqTpR=1.30') },
    @{ Name = 'live247_win_09_spread180'; Override = @('InpSpreadMedianMult=1.80','InpShieldMaxSpreadPoints=24','InpShieldSpreadSpikeMult=1.60') },
    @{ Name = 'live247_win_10_spread180_tp128'; Override = @('InpSpreadMedianMult=1.80','InpShieldMaxSpreadPoints=24','InpShieldSpreadSpikeMult=1.60','InpLqTpR=1.28') },
    @{ Name = 'live247_win_11_stop022'; Override = @('InpLqStopBufferAtr=0.22') },
    @{ Name = 'live247_win_12_struct025'; Override = @('InpLqStructuralTrailAtr=0.25') },
    @{ Name = 'live247_win_13_struct035'; Override = @('InpLqStructuralTrailAtr=0.35') }
)

$results = foreach ($case in $cases) {
    Write-Host ("Running {0}..." -f $case.Name)
    $overrides = $winnerBase + $case.Override
    $y2025 = Invoke-Period -RunName ($case.Name + '_2025') -FromDate '2025.01.02' -ToDate '2025.12.31' -Override $overrides
    $y2026 = Invoke-Period -RunName ($case.Name + '_2026') -FromDate '2026.01.01' -ToDate '2026.03.11' -Override $overrides
    $y2526 = Invoke-Period -RunName ($case.Name + '_2526') -FromDate '2025.01.02' -ToDate '2026.03.11' -Override $overrides

    [pscustomobject]@{
        run_name = $case.Name
        score = [math]::Round((Score-Case -Y2025 $y2025 -Y2026 $y2026 -Y2526 $y2526), 2)
        net_2025 = [double]$y2025.total_net_profit
        pf_2025 = [double]$y2025.profit_factor
        trades_2025 = [int]$y2025.total_trades
        net_2026 = [double]$y2026.total_net_profit
        pf_2026 = [double]$y2026.profit_factor
        trades_2026 = [int]$y2026.total_trades
        net_2526 = [double]$y2526.total_net_profit
        pf_2526 = [double]$y2526.profit_factor
        trades_2526 = [int]$y2526.total_trades
        eqdd_2526 = $y2526.equity_drawdown_raw
        overrides = $overrides
        report_2526 = $y2526.report_path
    }
}

$sorted = $results | Sort-Object @{ Expression = 'score'; Descending = $true }, @{ Expression = 'net_2526'; Descending = $true }, @{ Expression = 'net_2025'; Descending = $true }
$jsonPath = Join-Path $PSScriptRoot '..\..\mt5-portable\reports\live247_winner_refine.json'
$txtPath = Join-Path $PSScriptRoot '..\..\mt5-portable\reports\live247_winner_refine.txt'
$sorted | ConvertTo-Json -Depth 6 | Set-Content -Encoding ascii $jsonPath
$sorted | Format-Table run_name, score, net_2025, net_2026, net_2526, pf_2526, trades_2526, eqdd_2526 -AutoSize | Out-String | Set-Content -Encoding ascii $txtPath
Get-Content $txtPath


