param()
$ErrorActionPreference = 'Stop'
$base = @(
  'InpTradingMode=1','InpConfigTemplate=0','Debug=0','InpRiskPct=0.10','InpMaxTradesPerDay=80','InpMaxConsecLosses=6','InpMaxDailyDDPct=6.0','InpUseSessionFilter=true','InpTradeStartHour=5','InpTradeEndHour=23','InpUseSpreadFilter=false','InpUseDynamicSpreadGate=false','InpUseAtrRegimeGate=false','InpUseAutoPause=false','InpOnePosPerSymbol=true','InpAtrFilterMult=0.60','InpShieldCooldownBars=1','InpShieldSpreadSpikeMult=4.00','InpShieldMaxSpreadPoints=1200','InpShieldAtrShockMult=4.00','InpShieldCandleShockMult=5.00','InpShieldSlippageLimitPoints=80','InpMaxDeviationPoints=30','InpSlippagePoints=30','InpUseBreakEven=false','InpTrailStartAtr=1.20','InpTrailAtrMult=1.00','InpLqSwingLookback=6','InpLqSweepBufferAtr=0.00','InpLqSweepMaxAgeBars=6','InpLqMinDisplacementAtr=0.15','InpLqMssLookback=1','InpLqStopBufferAtr=0.30','InpLqTpR=1.25','InpLqEntryMode=2','InpLqRetestMaxAgeBars=2','InpLqRetestTolAtr=0.08','InpLqAllowStopFallback=true','InpLqUseStructuralTrail=true','InpLqStructuralTrailAtr=0.20'
)
$cases = @(
  @{ Name='sessref_5_21'; Extra=@('InpTradeStartHour=5','InpTradeEndHour=21') },
  @{ Name='sessref_5_22'; Extra=@('InpTradeStartHour=5','InpTradeEndHour=22') },
  @{ Name='sessref_6_20'; Extra=@('InpTradeStartHour=6','InpTradeEndHour=20') },
  @{ Name='sessref_6_21_dd5c5'; Extra=@('InpTradeStartHour=6','InpTradeEndHour=21','InpMaxDailyDDPct=5.0','InpMaxConsecLosses=5') },
  @{ Name='sessref_6_21_dd4c5'; Extra=@('InpTradeStartHour=6','InpTradeEndHour=21','InpMaxDailyDDPct=4.0','InpMaxConsecLosses=5') },
  @{ Name='sessref_5_22_dd5c5'; Extra=@('InpTradeStartHour=5','InpTradeEndHour=22','InpMaxDailyDDPct=5.0','InpMaxConsecLosses=5') }
)
$results = foreach($case in $cases){
  $overrides = @($base + $case.Extra)
  Write-Host "Running $($case.Name)..."
  $json = & powershell -ExecutionPolicy Bypass -Command "& { .\scripts\Run-Mt5Backtest.ps1 -RunName '$($case.Name)' -Override @('$($overrides -join "','")') }"
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
$sorted = $results | Sort-Object @{Expression='net';Descending=$true}, @{Expression='pf';Descending=$true}, @{Expression='trades';Descending=$true}
$sorted | ConvertTo-Json -Depth 4 | Set-Content -Encoding ascii '.\mt5-portable\reports\session_refine_search.json'
$sorted | Format-Table -AutoSize | Out-String | Set-Content -Encoding ascii '.\mt5-portable\reports\session_refine_search.txt'
Get-Content '.\mt5-portable\reports\session_refine_search.txt'
