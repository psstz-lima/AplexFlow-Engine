param()
$ErrorActionPreference = 'Stop'
$base = @(
  'InpTradingMode=1',
  'InpConfigTemplate=0',
  'Debug=0',
  'InpRiskPct=0.20',
  'InpMaxTradesPerDay=60',
  'InpMaxConsecLosses=8',
  'InpMaxDailyDDPct=8.0',
  'InpUseSessionFilter=false',
  'InpUseSpreadFilter=false',
  'InpUseDynamicSpreadGate=false',
  'InpUseAtrRegimeGate=false',
  'InpUseAutoPause=false',
  'InpOnePosPerSymbol=false',
  'InpAtrFilterMult=0.60',
  'InpShieldCooldownBars=1',
  'InpShieldSpreadSpikeMult=4.00',
  'InpShieldMaxSpreadPoints=1200',
  'InpShieldAtrShockMult=4.00',
  'InpShieldCandleShockMult=5.00',
  'InpShieldSlippageLimitPoints=80',
  'InpMaxDeviationPoints=30',
  'InpSlippagePoints=30',
  'InpUseBreakEven=false',
  'InpTrailStartAtr=1.20',
  'InpTrailAtrMult=1.00'
)
$cases = @(
  @{ Name='man_lq_ref_open'; Extra=@('InpLqSwingLookback=12','InpLqSweepBufferAtr=0.05','InpLqSweepMaxAgeBars=6','InpLqMinDisplacementAtr=0.45','InpLqMssLookback=3','InpLqStopBufferAtr=0.14','InpLqTpR=1.35','InpLqEntryMode=2','InpLqRetestMaxAgeBars=4','InpLqRetestTolAtr=0.12','InpLqAllowStopFallback=true','InpLqUseStructuralTrail=true','InpLqStructuralTrailAtr=0.30') },
  @{ Name='man_lq_hf1'; Extra=@('InpLqSwingLookback=8','InpLqSweepBufferAtr=0.02','InpLqSweepMaxAgeBars=6','InpLqMinDisplacementAtr=0.25','InpLqMssLookback=2','InpLqStopBufferAtr=0.10','InpLqTpR=1.55','InpLqEntryMode=0','InpLqRetestMaxAgeBars=2','InpLqRetestTolAtr=0.10','InpLqAllowStopFallback=true','InpLqUseStructuralTrail=true','InpLqStructuralTrailAtr=0.24') },
  @{ Name='man_lq_hf2'; Extra=@('InpLqSwingLookback=6','InpLqSweepBufferAtr=0.00','InpLqSweepMaxAgeBars=6','InpLqMinDisplacementAtr=0.15','InpLqMssLookback=1','InpLqStopBufferAtr=0.08','InpLqTpR=1.75','InpLqEntryMode=2','InpLqRetestMaxAgeBars=2','InpLqRetestTolAtr=0.08','InpLqAllowStopFallback=true','InpLqUseStructuralTrail=true','InpLqStructuralTrailAtr=0.20') },
  @{ Name='man_lq_hf3'; Extra=@('InpRiskPct=0.15','InpLqSwingLookback=5','InpLqSweepBufferAtr=0.00','InpLqSweepMaxAgeBars=8','InpLqMinDisplacementAtr=0.10','InpLqMssLookback=1','InpLqStopBufferAtr=0.06','InpLqTpR=2.00','InpLqEntryMode=0','InpLqRetestMaxAgeBars=1','InpLqRetestTolAtr=0.06','InpLqAllowStopFallback=true','InpLqUseStructuralTrail=true','InpLqStructuralTrailAtr=0.18') },
  @{ Name='man_lq_hf4'; Extra=@('InpRiskPct=0.12','InpLqSwingLookback=4','InpLqSweepBufferAtr=0.00','InpLqSweepMaxAgeBars=8','InpLqMinDisplacementAtr=0.08','InpLqMssLookback=1','InpLqStopBufferAtr=0.05','InpLqTpR=1.40','InpLqEntryMode=2','InpLqRetestMaxAgeBars=1','InpLqRetestTolAtr=0.05','InpLqAllowStopFallback=true','InpLqUseStructuralTrail=true','InpLqStructuralTrailAtr=0.16') }
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
$sorted = $results | Sort-Object trades, net -Descending
$sorted | ConvertTo-Json -Depth 4 | Set-Content -Encoding ascii '.\mt5-portable\reports\diag_lq_manual_results.json'
$sorted | Format-Table -AutoSize | Out-String | Set-Content -Encoding ascii '.\mt5-portable\reports\diag_lq_manual_results.txt'
Get-Content '.\mt5-portable\reports\diag_lq_manual_results.txt'
