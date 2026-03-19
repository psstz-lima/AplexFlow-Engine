param(
    [string]$RunName = "aplexflow_research",
    [string]$PortableRoot = (Join-Path $PSScriptRoot "..\mt5-portable"),
    [string]$HistoryFolder = "D:\ps_st\Downloads\Dados Hist*",
    [string]$BaseSetFile = (Join-Path $PSScriptRoot "..\mt5-portable\MQL5\Profiles\Tester\AplexFlow_Engine.set"),
    [string[]]$Symbols = @("EURUSD", "GBPUSD", "USDJPY", "AUDUSD", "USDCAD", "XAUUSD", "US500"),
    [switch]$UseImportedHistory,
    [switch]$AssumeImportedHistory,
    [string]$CsvSuffix = "_CSV",
    [string[]]$ExtraOverride = @(),
    [string]$PortfolioAnchor = "",
    [switch]$SkipSingles,
    [string]$FromDate = "2025.01.01",
    [string]$ToDate = "2026.03.11",
    [int]$Deposit = 200,
    [int]$Model = 4,
    [int]$ExecutionMode = 200,
    [ValidateSet("single", "slow_complete", "genetic")]
    [string]$OptimizationMode = "single",
    [int]$OptimizationCriterion = 6,
    [string]$ReportsDir = (Join-Path $PSScriptRoot "..\reports")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Expand-SymbolList {
    param([string[]]$InputSymbols)

    $expanded = New-Object System.Collections.Generic.List[string]
    foreach ($item in $InputSymbols) {
        if ([string]::IsNullOrWhiteSpace($item)) {
            continue
        }

        foreach ($symbol in ($item -split ",")) {
            $trimmed = $symbol.Trim()
            if (-not [string]::IsNullOrWhiteSpace($trimmed)) {
                $expanded.Add($trimmed) | Out-Null
            }
        }
    }

    if ($expanded.Count -eq 0) {
        throw "Nenhum simbolo valido foi informado em -Symbols."
    }

    return $expanded.ToArray()
}

$Symbols = Expand-SymbolList -InputSymbols $Symbols

$portableResolved = (Resolve-Path $PortableRoot).Path
$workspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$workspaceEngineFile = Join-Path $workspaceRoot "AplexFlow_Engine.mq5"
$workspaceModuleDir = Join-Path $workspaceRoot "AplexFlow"
$portableExpertsDir = Join-Path $portableResolved "MQL5\Experts\AplexFlow"
$portableModuleDir = Join-Path $portableExpertsDir "AplexFlow"
$compileTarget = Join-Path $portableResolved "MQL5\Experts\AplexFlow\AplexFlow_Engine.mq5"
$metaEditorPath = Join-Path $portableResolved "MetaEditor64.exe"
$compileLog = Join-Path $portableResolved "compile_research.log"
$reportsDir = $ReportsDir
$runBacktest = Join-Path $PSScriptRoot "Run-Mt5Backtest.ps1"
$importFolder = Join-Path $PSScriptRoot "Import-HistoricalFolder.ps1"
$symbolsDump = Join-Path $portableResolved "MQL5\Files\symbols_dump.txt"

if (-not (Test-Path $metaEditorPath)) {
    throw "Nao encontrei '$metaEditorPath'."
}

if (-not (Test-Path $workspaceEngineFile)) {
    throw "Nao encontrei '$workspaceEngineFile'."
}

if (-not (Test-Path $workspaceModuleDir)) {
    throw "Nao encontrei '$workspaceModuleDir'."
}

if (-not (Test-Path $portableExpertsDir)) {
    throw "Nao encontrei '$portableExpertsDir'."
}

Copy-Item -Path $workspaceEngineFile -Destination $compileTarget -Force
if (Test-Path $portableModuleDir) {
    Remove-Item -Path $portableModuleDir -Recurse -Force
}
Copy-Item -Path $workspaceModuleDir -Destination $portableExpertsDir -Recurse -Force

if (-not (Test-Path $compileTarget)) {
    throw "Nao encontrei '$compileTarget'."
}

New-Item -ItemType Directory -Force -Path $reportsDir | Out-Null

$availableSymbols = @()
if (Test-Path $symbolsDump) {
    $availableSymbols = Get-Content $symbolsDump |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ }
}

function Resolve-TesterSymbol {
    param(
        [string]$RequestedSymbol,
        [string[]]$AvailableSymbols,
        [string]$FallbackSymbol
    )

    if ([string]::IsNullOrWhiteSpace($RequestedSymbol)) {
        return $FallbackSymbol
    }

    if ($AvailableSymbols -contains $RequestedSymbol) {
        return $RequestedSymbol
    }

    $escaped = [regex]::Escape($RequestedSymbol)
    $nonCustomMatch = $AvailableSymbols |
        Where-Object { $_ -notlike '*_CSV' -and $_ -match $escaped } |
        Select-Object -First 1
    if ($nonCustomMatch) {
        return [string]$nonCustomMatch
    }

    $anyMatch = $AvailableSymbols |
        Where-Object { $_ -match $escaped } |
        Select-Object -First 1
    if ($anyMatch) {
        return [string]$anyMatch
    }

    return $FallbackSymbol
}

function Select-PortfolioAnchor {
    param(
        [string[]]$SymbolsList,
        [string]$RequestedAnchor
    )

    if (-not [string]::IsNullOrWhiteSpace($RequestedAnchor)) {
        return $RequestedAnchor
    }

    return $SymbolsList[0]
}

$defaultTesterSymbol = $Symbols[0]
if (-not ($availableSymbols -contains $defaultTesterSymbol) -and $availableSymbols.Count -gt 0) {
    $defaultTesterSymbol = [string]$availableSymbols[0]
}

$compileProc = Start-Process -FilePath $metaEditorPath `
    -ArgumentList @("/portable", "/compile:$compileTarget", "/log:$compileLog") `
    -WorkingDirectory $portableResolved `
    -Wait `
    -PassThru

$symbolMap = [ordered]@{}
foreach ($symbol in $Symbols) {
    $symbolMap[$symbol] = $symbol
}

$baseOverrides = @(
    "InpBacktestLatencyMs=$ExecutionMode",
    "InpEnableEvolutionExport=false",
    "InpEnableTelemetry=true"
)
if ($ExtraOverride.Count -gt 0) {
    $baseOverrides += $ExtraOverride
}

$importSummary = $null
if ($UseImportedHistory) {
    $importJson = & $importFolder `
        -HistoryFolder $HistoryFolder `
        -PortableRoot $portableResolved `
        -Symbols $Symbols `
        -Suffix $CsvSuffix
    $importSummary = $importJson | ConvertFrom-Json
    foreach ($item in $importSummary.results) {
        if ($item.imported) {
            $symbolMap[$item.symbol] = $item.custom_symbol
        }
    }
}
elseif ($AssumeImportedHistory) {
    $assumedResults = New-Object System.Collections.Generic.List[object]
    foreach ($symbol in $Symbols) {
        $customSymbol = "$symbol$CsvSuffix"
        $symbolMap[$symbol] = $customSymbol
        $assumedResults.Add([pscustomobject]@{
            symbol = $symbol
            imported = $true
            custom_symbol = $customSymbol
            assumed = $true
        }) | Out-Null
    }

    $importSummary = [pscustomobject]@{
        history_folder = $null
        portable_root = $portableResolved
        suffix = $CsvSuffix
        imported_symbols = ($assumedResults | ForEach-Object { $_.custom_symbol })
        imported_symbols_csv = (($assumedResults | ForEach-Object { $_.custom_symbol }) -join ",")
        results = $assumedResults
    }
}

$runs = New-Object System.Collections.Generic.List[object]

if (-not $SkipSingles) {
    foreach ($symbol in $Symbols) {
        $configSymbol = [string]$symbolMap[$symbol]
        $chartSymbol = Resolve-TesterSymbol -RequestedSymbol $symbol -AvailableSymbols $availableSymbols -FallbackSymbol $defaultTesterSymbol
        $runId = "$RunName.$symbol"
        $symbolOverrides = @("InpSymbols=$configSymbol") + $baseOverrides
        $json = & $runBacktest `
            -RunName $runId `
            -PortableRoot $portableResolved `
            -BaseSetFile $BaseSetFile `
            -Symbol $chartSymbol `
            -Period "M5" `
            -FromDate $FromDate `
        -ToDate $ToDate `
        -Deposit $Deposit `
        -Model $Model `
        -ExecutionMode $ExecutionMode `
        -OptimizationMode $OptimizationMode `
        -OptimizationCriterion $OptimizationCriterion `
        -Override $symbolOverrides

        $parsed = $json | ConvertFrom-Json
        $runs.Add([pscustomobject]@{
            scope = "single"
            symbol = $symbol
            tester_symbol = $chartSymbol
            config_symbol = $configSymbol
            run = $parsed
        }) | Out-Null
    }
}

$portfolioSymbols = @()
foreach ($symbol in $Symbols) {
    $portfolioSymbols += [string]$symbolMap[$symbol]
}
$portfolioCsv = ($portfolioSymbols -join ",")
$requestedPortfolioAnchor = Select-PortfolioAnchor -SymbolsList $Symbols -RequestedAnchor $PortfolioAnchor
$anchorSymbol = Resolve-TesterSymbol -RequestedSymbol $requestedPortfolioAnchor -AvailableSymbols $availableSymbols -FallbackSymbol $defaultTesterSymbol

$portfolioJson = & $runBacktest `
    -RunName "$RunName.portfolio" `
    -PortableRoot $portableResolved `
    -BaseSetFile $BaseSetFile `
    -Symbol $anchorSymbol `
    -Period "M5" `
    -FromDate $FromDate `
    -ToDate $ToDate `
    -Deposit $Deposit `
    -Model $Model `
    -ExecutionMode $ExecutionMode `
    -OptimizationMode $OptimizationMode `
    -OptimizationCriterion $OptimizationCriterion `
    -Override (@("InpSymbols=$portfolioCsv") + $baseOverrides)

$portfolioRun = $portfolioJson | ConvertFrom-Json
$runs.Add([pscustomobject]@{
    scope = "portfolio"
    symbol = "ALL"
    tester_symbol = $anchorSymbol
    requested_anchor = $requestedPortfolioAnchor
    config_symbol = $portfolioCsv
    run = $portfolioRun
}) | Out-Null

$summary = [pscustomobject]@{
    run_name = $RunName
    portable_root = $portableResolved
    compiled = @{
        exit_code = $compileProc.ExitCode
        log = $compileLog
    }
    imported_history = $importSummary
    execution_mode = $ExecutionMode
    optimization_mode = $OptimizationMode
    optimization_criterion = $OptimizationCriterion
    deposit = $Deposit
    from = $FromDate
    to = $ToDate
    runs = $runs
}

$summaryPath = Join-Path $reportsDir "$RunName.summary.json"
$summary | ConvertTo-Json -Depth 8 | Set-Content -Path $summaryPath -Encoding ASCII
$summary | ConvertTo-Json -Depth 8
