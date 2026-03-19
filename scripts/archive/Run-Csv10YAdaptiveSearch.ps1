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
$cases = @(
  @{ Name='csv10y_adp_01_base'; Ov=@('InpTradingMode=0','InpConfigTemplate=2','Debug=0') },
  @{ Name='csv10y_adp_02_noregime'; Ov=@('InpTradingMode=0','InpConfigTemplate=2','Debug=0','InpUseAtrRegimeGate=false') },
  @{ Name='csv10y_adp_03_noregime_nosession'; Ov=@('InpTradingMode=0','InpConfigTemplate=2','Debug=0','InpUseAtrRegimeGate=false','InpUseSessionFilter=false') },
  @{ Name='csv10y_adp_04_openfilters'; Ov=@('InpTradingMode=0','InpConfigTemplate=2','Debug=0','InpUseAtrRegimeGate=false','InpUseSessionFilter=false','InpUseSpreadFilter=false','InpUseDynamicSpreadGate=false') },
  @{ Name='csv10y_adp_05_breakout_loose'; Ov=@('InpTradingMode=0','InpConfigTemplate=2','Debug=0','InpUseAtrRegimeGate=false','InpUseSessionFilter=false','InpUseSpreadFilter=false','InpUseDynamicSpreadGate=false','InpMinTrendStrengthAtr=0.020','InpBreakoutBodyAtrMin=0.08','InpBreakoutCloseStrengthMin=0.50','InpStopAtrMult=1.80','InpTpAtrMult=1.80','InpBreakEvenAtrTrigger=0.90','InpTrailStartAtr=1.20','InpTrailAtrMult=1.10','InpMaxTradesPerDay=20') },
  @{ Name='csv10y_adp_06_breakout_rr'; Ov=@('InpTradingMode=0','InpConfigTemplate=2','Debug=0','InpUseAtrRegimeGate=false','InpUseSessionFilter=false','InpUseSpreadFilter=false','InpUseDynamicSpreadGate=false','InpMinTrendStrengthAtr=0.018','InpBreakoutBodyAtrMin=0.07','InpBreakoutCloseStrengthMin=0.49','InpStopAtrMult=1.60','InpTpAtrMult=2.10','InpBreakEvenAtrTrigger=1.10','InpTrailStartAtr=1.50','InpTrailAtrMult=1.25','InpMaxTradesPerDay=24') },
  @{ Name='csv10y_adp_07_session_6_21'; Ov=@('InpTradingMode=0','InpConfigTemplate=2','Debug=0','InpUseAtrRegimeGate=false','InpUseSessionFilter=true','InpTradeStartHour=6','InpTradeEndHour=21','InpUseSpreadFilter=false','InpUseDynamicSpreadGate=false','InpMinTrendStrengthAtr=0.020','InpBreakoutBodyAtrMin=0.08','InpBreakoutCloseStrengthMin=0.50','InpStopAtrMult=1.70','InpTpAtrMult=1.90') },
  @{ Name='csv10y_adp_08_session_6_18'; Ov=@('InpTradingMode=0','InpConfigTemplate=2','Debug=0','InpUseAtrRegimeGate=false','InpUseSessionFilter=true','InpTradeStartHour=6','InpTradeEndHour=18','InpUseSpreadFilter=false','InpUseDynamicSpreadGate=false','InpMinTrendStrengthAtr=0.022','InpBreakoutBodyAtrMin=0.09','InpBreakoutCloseStrengthMin=0.52','InpStopAtrMult=1.70','InpTpAtrMult=1.85') },
  @{ Name='csv10y_adp_09_fastswitch'; Ov=@('InpTradingMode=0','InpConfigTemplate=2','Debug=0','InpUseAtrRegimeGate=false','InpUseSpreadFilter=false','InpUseDynamicSpreadGate=false','InpAdaptConfirmBars=1','InpAdaptMinBarsBetweenChanges=1','InpAdaptMaxChangesPerDay=40','InpMinTrendStrengthAtr=0.018','InpBreakoutBodyAtrMin=0.07','InpBreakoutCloseStrengthMin=0.49','InpStopAtrMult=1.70','InpTpAtrMult=1.90') },
  @{ Name='csv10y_adp_10_defensive_rr'; Ov=@('InpTradingMode=0','InpConfigTemplate=2','Debug=0','InpUseAtrRegimeGate=true','InpUseSessionFilter=true','InpTradeStartHour=6','InpTradeEndHour=21','InpStopAtrMult=1.40','InpTpAtrMult=2.20','InpBreakEvenAtrTrigger=1.20','InpTrailStartAtr=1.60','InpTrailAtrMult=1.30','InpMaxTradesPerDay=12') }
)
$results = foreach($case in $cases){ Run-Case $case.Name $case.Ov }
$sorted = $results | Sort-Object @{Expression='net';Descending=$true}, @{Expression='pf';Descending=$true}, @{Expression='trades';Descending=$true}
$sorted | ConvertTo-Json -Depth 4 | Set-Content -Encoding ascii '.\mt5-portable\reports\csv10y_adaptive_search.json'
$sorted | Format-Table -AutoSize | Out-String | Set-Content -Encoding ascii '.\mt5-portable\reports\csv10y_adaptive_search.txt'
Get-Content '.\mt5-portable\reports\csv10y_adaptive_search.txt'


