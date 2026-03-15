param()
$ErrorActionPreference = 'Stop'
function Run-Case($name, $overrides){
  Write-Host "Running $name..."
  $json = & powershell -ExecutionPolicy Bypass -Command "& { .\scripts\Run-Mt5Backtest.ps1 -RunName '$name' -Symbol 'XAUUSD_CSV' -FromDate '2016.02.17' -ToDate '2026.02.17' -Model 1 -Override @('$($overrides -join "','")') }"
  $obj = $json | ConvertFrom-Json
  [pscustomobject]@{
    run_name = $obj.run_name
    net = [double]$obj.total_net_profit
    pf = [double]$obj.profit_factor
    trades = [int]$obj.total_trades
    balance_dd = $obj.balance_drawdown_raw
    equity_dd = $obj.equity_drawdown_raw
    report = $obj.report_path
  }
}
$base = @('InpTradingMode=1','InpConfigTemplate=0','Debug=0','InpRiskPct=0.06','InpMaxTradesPerDay=30','InpMaxConsecLosses=3','InpMaxDailyDDPct=4.0','InpUseSessionFilter=true','InpTradeStartHour=6','InpTradeEndHour=20','InpUseSpreadFilter=true','InpMaxSpreadAtrFrac=0.18','InpUseDynamicSpreadGate=true','InpSpreadMedianLen=200','InpSpreadMedianMult=1.60','InpOnePosPerSymbol=true','InpAtrFilterMult=0.98','InpUseBreakEven=true','InpBreakEvenAtrTrigger=0.45','InpBreakEvenOffsetPoints=5','InpTrailStartAtr=0.95','InpTrailAtrMult=1.15','InpLqSwingLookback=12','InpLqSweepBufferAtr=0.08','InpLqSweepMaxAgeBars=4','InpLqMinDisplacementAtr=0.85','InpLqMssLookback=4','InpLqStopBufferAtr=0.26','InpLqTpR=1.20','InpLqEntryMode=2','InpLqRetestMaxAgeBars=2','InpLqRetestTolAtr=0.07','InpLqAllowStopFallback=true','InpLqUseStructuralTrail=true','InpLqStructuralTrailAtr=0.30')
$cases = @(
  @{ Name='csv10y_lqbest_01_base'; Add=@() },
  @{ Name='csv10y_lqbest_02_session521'; Add=@('InpTradeStartHour=5','InpTradeEndHour=21') },
  @{ Name='csv10y_lqbest_03_spread020'; Add=@('InpMaxSpreadAtrFrac=0.20') },
  @{ Name='csv10y_lqbest_04_spread022'; Add=@('InpMaxSpreadAtrFrac=0.22') },
  @{ Name='csv10y_lqbest_05_tp110'; Add=@('InpLqTpR=1.10') },
  @{ Name='csv10y_lqbest_06_tp125'; Add=@('InpLqTpR=1.25') },
  @{ Name='csv10y_lqbest_07_beoff'; Add=@('InpUseBreakEven=false','InpTrailStartAtr=1.20','InpTrailAtrMult=1.20') },
  @{ Name='csv10y_lqbest_08_session521_tp110'; Add=@('InpTradeStartHour=5','InpTradeEndHour=21','InpLqTpR=1.10') },
  @{ Name='csv10y_lqbest_09_session521_spread022'; Add=@('InpTradeStartHour=5','InpTradeEndHour=21','InpMaxSpreadAtrFrac=0.22') },
  @{ Name='csv10y_lqbest_10_session521_tp110_spread022'; Add=@('InpTradeStartHour=5','InpTradeEndHour=21','InpLqTpR=1.10','InpMaxSpreadAtrFrac=0.22') },
  @{ Name='csv10y_lqbest_11_swing10'; Add=@('InpLqSwingLookback=10') },
  @{ Name='csv10y_lqbest_12_mss3'; Add=@('InpLqMssLookback=3') }
)
$results = foreach($case in $cases){ Run-Case $case.Name (@($base + $case.Add)) }
$sorted = $results | Sort-Object @{Expression='net';Descending=$true}, @{Expression='pf';Descending=$true}, @{Expression='trades';Descending=$true}
$sorted | ConvertTo-Json -Depth 4 | Set-Content -Encoding ascii '.\mt5-portable\reports\csv10y_liquidity_best_refine.json'
$sorted | Format-Table -AutoSize | Out-String | Set-Content -Encoding ascii '.\mt5-portable\reports\csv10y_liquidity_best_refine.txt'
Get-Content '.\mt5-portable\reports\csv10y_liquidity_best_refine.txt'
