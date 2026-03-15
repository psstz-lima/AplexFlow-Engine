param()
$ErrorActionPreference = 'Stop'
$base = @(
  'InpTradingMode=1','InpConfigTemplate=0','Debug=0','InpRiskPct=0.20','InpMaxTradesPerDay=80','InpMaxConsecLosses=12','InpMaxDailyDDPct=20.0','InpUseSessionFilter=false','InpUseSpreadFilter=false','InpUseDynamicSpreadGate=false','InpUseAtrRegimeGate=false','InpUseAutoPause=false','InpOnePosPerSymbol=true','InpAtrFilterMult=0.60','InpShieldCooldownBars=1','InpShieldSpreadSpikeMult=4.00','InpShieldMaxSpreadPoints=1200','InpShieldAtrShockMult=4.00','InpShieldCandleShockMult=5.00','InpShieldSlippageLimitPoints=80','InpMaxDeviationPoints=30','InpSlippagePoints=30','InpUseBreakEven=false','InpTrailStartAtr=1.20','InpTrailAtrMult=1.00','InpLqSwingLookback=6','InpLqSweepBufferAtr=0.00','InpLqSweepMaxAgeBars=6','InpLqMinDisplacementAtr=0.15','InpLqMssLookback=1','InpLqStopBufferAtr=0.30','InpLqTpR=1.25','InpLqEntryMode=2','InpLqRetestMaxAgeBars=2','InpLqRetestTolAtr=0.08','InpLqAllowStopFallback=true','InpLqUseStructuralTrail=true','InpLqStructuralTrailAtr=0.20'
)
$cases = @(
  @{ Name='riskctl_01_base'; Extra=@() },
  @{ Name='riskctl_02_risk010'; Extra=@('InpRiskPct=0.10') },
  @{ Name='riskctl_03_risk008'; Extra=@('InpRiskPct=0.08') },
  @{ Name='riskctl_04_risk005'; Extra=@('InpRiskPct=0.05') },
  @{ Name='riskctl_05_dd6_consec6'; Extra=@('InpMaxDailyDDPct=6.0','InpMaxConsecLosses=6') },
  @{ Name='riskctl_06_dd4_consec5'; Extra=@('InpMaxDailyDDPct=4.0','InpMaxConsecLosses=5') },
  @{ Name='riskctl_07_risk010_dd6_consec6'; Extra=@('InpRiskPct=0.10','InpMaxDailyDDPct=6.0','InpMaxConsecLosses=6') },
  @{ Name='riskctl_08_session_5_23'; Extra=@('InpUseSessionFilter=true','InpTradeStartHour=5','InpTradeEndHour=23') },
  @{ Name='riskctl_09_session_6_18'; Extra=@('InpUseSessionFilter=true','InpTradeStartHour=6','InpTradeEndHour=18') },
  @{ Name='riskctl_10_spread025'; Extra=@('InpUseSpreadFilter=true','InpMaxSpreadAtrFrac=0.25') },
  @{ Name='riskctl_11_spread035'; Extra=@('InpUseSpreadFilter=true','InpMaxSpreadAtrFrac=0.35') },
  @{ Name='riskctl_12_risk010_dd6_session523'; Extra=@('InpRiskPct=0.10','InpMaxDailyDDPct=6.0','InpMaxConsecLosses=6','InpUseSessionFilter=true','InpTradeStartHour=5','InpTradeEndHour=23') }
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
$sorted | ConvertTo-Json -Depth 4 | Set-Content -Encoding ascii '.\mt5-portable\reports\risk_control_search.json'
$sorted | Format-Table -AutoSize | Out-String | Set-Content -Encoding ascii '.\mt5-portable\reports\risk_control_search.txt'
Get-Content '.\mt5-portable\reports\risk_control_search.txt'
