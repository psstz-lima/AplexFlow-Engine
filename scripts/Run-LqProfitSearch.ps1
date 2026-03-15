param()
$ErrorActionPreference = 'Stop'
$common = @(
  'InpTradingMode=1',
  'InpConfigTemplate=0',
  'Debug=0',
  'InpRiskPct=0.20',
  'InpMaxTradesPerDay=80',
  'InpMaxConsecLosses=12',
  'InpMaxDailyDDPct=20.0',
  'InpUseSessionFilter=false',
  'InpUseAtrRegimeGate=false',
  'InpUseAutoPause=false',
  'InpAtrFilterMult=0.60',
  'InpShieldCooldownBars=1',
  'InpShieldSpreadSpikeMult=4.00',
  'InpShieldMaxSpreadPoints=1200',
  'InpShieldAtrShockMult=4.00',
  'InpShieldCandleShockMult=5.00',
  'InpShieldSlippageLimitPoints=80',
  'InpMaxDeviationPoints=30',
  'InpSlippagePoints=30',
  'InpLqSwingLookback=6',
  'InpLqSweepBufferAtr=0.00',
  'InpLqSweepMaxAgeBars=6',
  'InpLqMinDisplacementAtr=0.15',
  'InpLqMssLookback=1',
  'InpLqStopBufferAtr=0.08',
  'InpLqTpR=1.75',
  'InpLqEntryMode=2',
  'InpLqRetestMaxAgeBars=2',
  'InpLqRetestTolAtr=0.08',
  'InpLqAllowStopFallback=true',
  'InpLqUseStructuralTrail=true',
  'InpLqStructuralTrailAtr=0.20'
)
$cases = @(
  @{ Name='search_lq_01_base'; Extra=@('InpUseSpreadFilter=false','InpUseDynamicSpreadGate=false','InpOnePosPerSymbol=false','InpUseBreakEven=false','InpTrailStartAtr=1.20','InpTrailAtrMult=1.00') },
  @{ Name='search_lq_02_tp125'; Extra=@('InpUseSpreadFilter=false','InpUseDynamicSpreadGate=false','InpOnePosPerSymbol=false','InpUseBreakEven=false','InpTrailStartAtr=1.20','InpTrailAtrMult=1.00','InpLqTpR=1.25') },
  @{ Name='search_lq_03_tp110'; Extra=@('InpUseSpreadFilter=false','InpUseDynamicSpreadGate=false','InpOnePosPerSymbol=false','InpUseBreakEven=false','InpTrailStartAtr=1.20','InpTrailAtrMult=1.00','InpLqTpR=1.10') },
  @{ Name='search_lq_04_disp020_tp125'; Extra=@('InpUseSpreadFilter=false','InpUseDynamicSpreadGate=false','InpOnePosPerSymbol=false','InpUseBreakEven=false','InpTrailStartAtr=1.20','InpTrailAtrMult=1.00','InpLqMinDisplacementAtr=0.20','InpLqTpR=1.25') },
  @{ Name='search_lq_05_disp025_tp125'; Extra=@('InpUseSpreadFilter=false','InpUseDynamicSpreadGate=false','InpOnePosPerSymbol=false','InpUseBreakEven=false','InpTrailStartAtr=1.20','InpTrailAtrMult=1.00','InpLqMinDisplacementAtr=0.25','InpLqTpR=1.25') },
  @{ Name='search_lq_06_disp030_tp125'; Extra=@('InpUseSpreadFilter=false','InpUseDynamicSpreadGate=false','InpOnePosPerSymbol=false','InpUseBreakEven=false','InpTrailStartAtr=1.20','InpTrailAtrMult=1.00','InpLqMinDisplacementAtr=0.30','InpLqTpR=1.25') },
  @{ Name='search_lq_07_disp025_stop010_tp140'; Extra=@('InpUseSpreadFilter=false','InpUseDynamicSpreadGate=false','InpOnePosPerSymbol=false','InpUseBreakEven=false','InpTrailStartAtr=1.20','InpTrailAtrMult=1.00','InpLqMinDisplacementAtr=0.25','InpLqStopBufferAtr=0.10','InpLqTpR=1.40') },
  @{ Name='search_lq_08_onepos'; Extra=@('InpUseSpreadFilter=false','InpUseDynamicSpreadGate=false','InpOnePosPerSymbol=true','InpUseBreakEven=false','InpTrailStartAtr=1.20','InpTrailAtrMult=1.00','InpLqTpR=1.25') },
  @{ Name='search_lq_09_be_fast'; Extra=@('InpUseSpreadFilter=false','InpUseDynamicSpreadGate=false','InpOnePosPerSymbol=false','InpUseBreakEven=true','InpBreakEvenAtrTrigger=0.30','InpBreakEvenOffsetPoints=3','InpTrailStartAtr=0.70','InpTrailAtrMult=0.90','InpLqTpR=1.25') },
  @{ Name='search_lq_10_be_mid'; Extra=@('InpUseSpreadFilter=false','InpUseDynamicSpreadGate=false','InpOnePosPerSymbol=false','InpUseBreakEven=true','InpBreakEvenAtrTrigger=0.40','InpBreakEvenOffsetPoints=5','InpTrailStartAtr=0.90','InpTrailAtrMult=1.00','InpLqTpR=1.40','InpLqMinDisplacementAtr=0.20') },
  @{ Name='search_lq_11_buf002_disp025'; Extra=@('InpUseSpreadFilter=false','InpUseDynamicSpreadGate=false','InpOnePosPerSymbol=true','InpUseBreakEven=true','InpBreakEvenAtrTrigger=0.30','InpBreakEvenOffsetPoints=3','InpTrailStartAtr=0.70','InpTrailAtrMult=0.90','InpLqSweepBufferAtr=0.02','InpLqMinDisplacementAtr=0.25','InpLqTpR=1.25') },
  @{ Name='search_lq_12_buf004_disp030'; Extra=@('InpUseSpreadFilter=false','InpUseDynamicSpreadGate=false','InpOnePosPerSymbol=true','InpUseBreakEven=true','InpBreakEvenAtrTrigger=0.30','InpBreakEvenOffsetPoints=3','InpTrailStartAtr=0.70','InpTrailAtrMult=0.90','InpLqSweepBufferAtr=0.04','InpLqMinDisplacementAtr=0.30','InpLqTpR=1.25') },
  @{ Name='search_lq_13_spreadfilter'; Extra=@('InpUseSpreadFilter=true','InpMaxSpreadAtrFrac=0.25','InpUseDynamicSpreadGate=false','InpOnePosPerSymbol=false','InpUseBreakEven=true','InpBreakEvenAtrTrigger=0.30','InpBreakEvenOffsetPoints=3','InpTrailStartAtr=0.70','InpTrailAtrMult=0.90','InpLqTpR=1.25','InpLqMinDisplacementAtr=0.20') },
  @{ Name='search_lq_14_spreadfilter_onepos'; Extra=@('InpUseSpreadFilter=true','InpMaxSpreadAtrFrac=0.20','InpUseDynamicSpreadGate=false','InpOnePosPerSymbol=true','InpUseBreakEven=true','InpBreakEvenAtrTrigger=0.30','InpBreakEvenOffsetPoints=3','InpTrailStartAtr=0.70','InpTrailAtrMult=0.90','InpLqTpR=1.25','InpLqMinDisplacementAtr=0.25') }
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
$sorted | ConvertTo-Json -Depth 4 | Set-Content -Encoding ascii '.\mt5-portable\reports\search_lq_results.json'
$sorted | Format-Table -AutoSize | Out-String | Set-Content -Encoding ascii '.\mt5-portable\reports\search_lq_results.txt'
Get-Content '.\mt5-portable\reports\search_lq_results.txt'
