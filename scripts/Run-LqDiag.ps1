param()
$ErrorActionPreference = 'Stop'
$cases = @(
  @{ Name='diag_lq_base'; Overrides=@('InpTradingMode=1','InpConfigTemplate=2','Debug=0') },
  @{ Name='diag_lq_noregime'; Overrides=@('InpTradingMode=1','InpConfigTemplate=2','Debug=0','InpUseAtrRegimeGate=false') },
  @{ Name='diag_lq_noregime_nosession'; Overrides=@('InpTradingMode=1','InpConfigTemplate=2','Debug=0','InpUseAtrRegimeGate=false','InpUseSessionFilter=false') },
  @{ Name='diag_lq_noregime_nosession_nopause'; Overrides=@('InpTradingMode=1','InpConfigTemplate=2','Debug=0','InpUseAtrRegimeGate=false','InpUseSessionFilter=false','InpUseAutoPause=false') },
  @{ Name='diag_lq_open_filters'; Overrides=@('InpTradingMode=1','InpConfigTemplate=2','Debug=0','InpUseAtrRegimeGate=false','InpUseSessionFilter=false','InpUseAutoPause=false','InpUseDynamicSpreadGate=false','InpShieldCooldownBars=1','InpShieldSpreadSpikeMult=3.00','InpShieldMaxSpreadPoints=900','InpShieldAtrShockMult=3.00','InpShieldCandleShockMult=4.00','InpShieldSlippageLimitPoints=50','InpMaxTradesPerDay=40') },
  @{ Name='diag_lq_open_fast'; Overrides=@('InpTradingMode=1','InpConfigTemplate=2','Debug=0','InpUseAtrRegimeGate=false','InpUseSessionFilter=false','InpUseAutoPause=false','InpUseDynamicSpreadGate=false','InpShieldCooldownBars=1','InpShieldSpreadSpikeMult=3.00','InpShieldMaxSpreadPoints=900','InpShieldAtrShockMult=3.00','InpShieldCandleShockMult=4.00','InpShieldSlippageLimitPoints=50','InpLqSwingLookback=10','InpLqSweepBufferAtr=0.20','InpLqSweepMaxAgeBars=6','InpLqMinDisplacementAtr=0.50','InpLqMssLookback=3','InpLqStopBufferAtr=0.12','InpLqTpR=1.35','InpLqEntryMode=2','InpLqRetestMaxAgeBars=4','InpLqRetestTolAtr=0.12','InpMaxTradesPerDay=40') },
  @{ Name='diag_lq_open_faster'; Overrides=@('InpTradingMode=1','InpConfigTemplate=2','Debug=0','InpUseAtrRegimeGate=false','InpUseSessionFilter=false','InpUseAutoPause=false','InpUseDynamicSpreadGate=false','InpShieldCooldownBars=1','InpShieldSpreadSpikeMult=3.00','InpShieldMaxSpreadPoints=900','InpShieldAtrShockMult=3.00','InpShieldCandleShockMult=4.00','InpShieldSlippageLimitPoints=50','InpLqSwingLookback=8','InpLqSweepBufferAtr=0.08','InpLqSweepMaxAgeBars=6','InpLqMinDisplacementAtr=0.35','InpLqMssLookback=2','InpLqStopBufferAtr=0.10','InpLqTpR=1.50','InpLqEntryMode=0','InpLqRetestMaxAgeBars=2','InpLqRetestTolAtr=0.10','InpMaxTradesPerDay=60') }
)
$results = foreach($case in $cases){
  Write-Host "Running $($case.Name)..."
  $json = & powershell -ExecutionPolicy Bypass -Command "& { .\scripts\Run-Mt5Backtest.ps1 -RunName '$($case.Name)' -Override @('$($case.Overrides -join "','")') }"
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
$results | Sort-Object trades, net -Descending | ConvertTo-Json -Depth 4 | Set-Content -Encoding ascii '.\mt5-portable\reports\diag_lq_results.json'
$results | Sort-Object trades, net -Descending | Format-Table -AutoSize | Out-String | Set-Content -Encoding ascii '.\mt5-portable\reports\diag_lq_results.txt'
Get-Content '.\mt5-portable\reports\diag_lq_results.txt'
