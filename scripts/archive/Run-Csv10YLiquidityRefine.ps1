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
$base = @('InpTradingMode=1','InpConfigTemplate=0','Debug=0','InpRiskPct=0.06','InpMaxTradesPerDay=30','InpMaxConsecLosses=3','InpMaxDailyDDPct=4.0','InpUseSessionFilter=true','InpTradeStartHour=6','InpTradeEndHour=20','InpUseSpreadFilter=true','InpMaxSpreadAtrFrac=0.18','InpUseDynamicSpreadGate=true','InpSpreadMedianLen=200','InpSpreadMedianMult=1.60','InpOnePosPerSymbol=true','InpAtrFilterMult=0.98','InpUseBreakEven=true','InpBreakEvenAtrTrigger=0.45','InpBreakEvenOffsetPoints=5','InpTrailStartAtr=0.95','InpTrailAtrMult=1.15','InpLqSwingLookback=12','InpLqSweepBufferAtr=0.08','InpLqSweepMaxAgeBars=4','InpLqMinDisplacementAtr=0.90','InpLqMssLookback=4','InpLqStopBufferAtr=0.26','InpLqTpR=1.20','InpLqEntryMode=2','InpLqRetestMaxAgeBars=2','InpLqRetestTolAtr=0.07','InpLqAllowStopFallback=true','InpLqUseStructuralTrail=true','InpLqStructuralTrailAtr=0.30')
$cases = @(
  @{ Name='csv10y_lqref_01_base'; Add=@() },
  @{ Name='csv10y_lqref_02_risk008'; Add=@('InpRiskPct=0.08') },
  @{ Name='csv10y_lqref_03_risk010'; Add=@('InpRiskPct=0.10') },
  @{ Name='csv10y_lqref_04_session621'; Add=@('InpTradeEndHour=21') },
  @{ Name='csv10y_lqref_05_session521'; Add=@('InpTradeStartHour=5','InpTradeEndHour=21') },
  @{ Name='csv10y_lqref_06_disp085'; Add=@('InpLqMinDisplacementAtr=0.85') },
  @{ Name='csv10y_lqref_07_disp080'; Add=@('InpLqMinDisplacementAtr=0.80') },
  @{ Name='csv10y_lqref_08_atr095'; Add=@('InpAtrFilterMult=0.95') },
  @{ Name='csv10y_lqref_09_tp130'; Add=@('InpLqTpR=1.30') },
  @{ Name='csv10y_lqref_10_tp110'; Add=@('InpLqTpR=1.10') },
  @{ Name='csv10y_lqref_11_spread020'; Add=@('InpMaxSpreadAtrFrac=0.20') },
  @{ Name='csv10y_lqref_12_spread022'; Add=@('InpMaxSpreadAtrFrac=0.22') },
  @{ Name='csv10y_lqref_13_be035'; Add=@('InpBreakEvenAtrTrigger=0.35','InpBreakEvenOffsetPoints=4','InpTrailStartAtr=0.90','InpTrailAtrMult=1.10') },
  @{ Name='csv10y_lqref_14_dd5c4'; Add=@('InpMaxConsecLosses=4','InpMaxDailyDDPct=5.0') },
  @{ Name='csv10y_lqref_15_disp085_session621'; Add=@('InpLqMinDisplacementAtr=0.85','InpTradeEndHour=21') }
)
$results = foreach($case in $cases){ Run-Case $case.Name (@($base + $case.Add)) }
$sorted = $results | Sort-Object @{Expression='net';Descending=$true}, @{Expression='pf';Descending=$true}, @{Expression='trades';Descending=$true}
$sorted | ConvertTo-Json -Depth 4 | Set-Content -Encoding ascii '.\mt5-portable\reports\csv10y_liquidity_refine.json'
$sorted | Format-Table -AutoSize | Out-String | Set-Content -Encoding ascii '.\mt5-portable\reports\csv10y_liquidity_refine.txt'
Get-Content '.\mt5-portable\reports\csv10y_liquidity_refine.txt'


