param()
$ErrorActionPreference = 'Stop'
$common = @(
  'InpTradingMode=1','InpConfigTemplate=0','Debug=0','InpRiskPct=0.20','InpMaxTradesPerDay=80','InpMaxConsecLosses=12','InpMaxDailyDDPct=20.0','InpUseSessionFilter=false','InpUseSpreadFilter=false','InpUseDynamicSpreadGate=false','InpUseAtrRegimeGate=false','InpUseAutoPause=false','InpOnePosPerSymbol=true','InpAtrFilterMult=0.60','InpShieldCooldownBars=1','InpShieldSpreadSpikeMult=4.00','InpShieldMaxSpreadPoints=1200','InpShieldAtrShockMult=4.00','InpShieldCandleShockMult=5.00','InpShieldSlippageLimitPoints=80','InpMaxDeviationPoints=30','InpSlippagePoints=30','InpUseBreakEven=false','InpTrailStartAtr=1.20','InpTrailAtrMult=1.00','InpLqSwingLookback=6','InpLqSweepBufferAtr=0.00','InpLqSweepMaxAgeBars=6','InpLqMinDisplacementAtr=0.15','InpLqMssLookback=1','InpLqEntryMode=2','InpLqRetestMaxAgeBars=2','InpLqRetestTolAtr=0.08','InpLqAllowStopFallback=true','InpLqUseStructuralTrail=true','InpLqStructuralTrailAtr=0.20'
)
$cases = @(
  @{ Name='onepos_tight_base'; Extra=@('InpLqStopBufferAtr=0.08','InpLqTpR=1.75') },
  @{ Name='onepos_stop020_tp125'; Extra=@('InpLqStopBufferAtr=0.20','InpLqTpR=1.25') },
  @{ Name='onepos_stop025_tp125'; Extra=@('InpLqStopBufferAtr=0.25','InpLqTpR=1.25') },
  @{ Name='onepos_stop030_tp125'; Extra=@('InpLqStopBufferAtr=0.30','InpLqTpR=1.25') },
  @{ Name='onepos_stop020_tp110'; Extra=@('InpLqStopBufferAtr=0.20','InpLqTpR=1.10') },
  @{ Name='onepos_stop025_tp110'; Extra=@('InpLqStopBufferAtr=0.25','InpLqTpR=1.10') },
  @{ Name='onepos_buf002_disp020_stop020_tp125'; Extra=@('InpLqSweepBufferAtr=0.02','InpLqMinDisplacementAtr=0.20','InpLqStopBufferAtr=0.20','InpLqTpR=1.25') },
  @{ Name='onepos_buf002_disp020_stop020_tp125_be'; Extra=@('InpLqSweepBufferAtr=0.02','InpLqMinDisplacementAtr=0.20','InpLqStopBufferAtr=0.20','InpLqTpR=1.25','InpUseBreakEven=true','InpBreakEvenAtrTrigger=0.35','InpBreakEvenOffsetPoints=4','InpTrailStartAtr=0.90','InpTrailAtrMult=1.00') }
)
$results = foreach($case in $cases){
  $overrides = @($common + $case.Extra)
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
$sorted = $results | Sort-Object @{Expression='pf';Descending=$true}, @{Expression='net';Descending=$true}, @{Expression='trades';Descending=$true}
$sorted | ConvertTo-Json -Depth 4 | Set-Content -Encoding ascii '.\mt5-portable\reports\onepos_stop_search.json'
$sorted | Format-Table -AutoSize | Out-String | Set-Content -Encoding ascii '.\mt5-portable\reports\onepos_stop_search.txt'
Get-Content '.\mt5-portable\reports\onepos_stop_search.txt'
