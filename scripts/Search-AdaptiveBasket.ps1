param(
    [string]$RunPrefix = "basket_search",
    [string]$PortableRoot = (Join-Path $PSScriptRoot "..\mt5-portable"),
    [string]$HistoryFolder = "D:\ps_st\Downloads\Dados Hist*",
    [string]$BaseSetFile = (Join-Path $PSScriptRoot "..\mt5-portable\MQL5\Profiles\Tester\AplexFlow_Engine.set"),
    [string[]]$Symbols = @("EURUSD", "GBPUSD", "USDJPY", "AUDUSD", "USDCAD", "XAUUSD", "US500"),
    [string]$CsvSuffix = "_CSV",
    [ValidateSet("broad","refine","dedicated","frontier")]
    [string]$ProfileMode = "broad",
    [string]$TrainFromDate = "2026.01.01",
    [string]$TrainToDate = "2026.01.31",
    [string]$ValidateFromDate = "2026.01.01",
    [string]$ValidateToDate = "2026.03.11",
    [int]$Deposit = 200,
    [int]$ExecutionMode = 200,
    [int]$TopToValidate = 2,
    [ValidateRange(1, 32)]
    [int]$MaxParallel = 1,
    [switch]$PrimeWorkers = $true,
    [string]$WorkersRoot = (Join-Path $PSScriptRoot "..\mt5-workers"),
    [ValidateSet("isolated", "shared")]
    [string]$WorkerBasesMode = "isolated",
    [ValidateSet("single", "slow_complete", "genetic")]
    [string]$OptimizationMode = "single",
    [int]$OptimizationCriterion = 6,
    [switch]$EnsureImportedHistory = $true,
    [string]$OutputPath = ""
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

function Get-PortfolioRun {
    param([object]$Summary)

    return ($Summary.runs | Where-Object { $_.scope -eq "portfolio" } | Select-Object -First 1)
}

function Get-DrawdownPercent {
    param([string]$RawValue)

    if ([string]::IsNullOrWhiteSpace($RawValue)) {
        return 0.0
    }

    $match = [regex]::Match($RawValue, "\(([-\d\.]+)%\)")
    if ($match.Success) {
        return [double]::Parse($match.Groups[1].Value, [System.Globalization.CultureInfo]::InvariantCulture)
    }

    $first = [regex]::Match($RawValue, "[-\d\.]+")
    if ($first.Success) {
        return [double]::Parse($first.Value, [System.Globalization.CultureInfo]::InvariantCulture)
    }

    return 0.0
}

function Score-PortfolioRun {
    param([object]$Run)

    $pf = [double]$Run.profit_factor
    $net = [double]$Run.total_net_profit
    $balance = [double]$Run.final_balance
    $trades = [int]$Run.total_trades
    $equityDdPct = Get-DrawdownPercent -RawValue $Run.equity_drawdown_raw
    $ddOver = [Math]::Max(0.0, $equityDdPct - 10.0)
    $tradePenalty = 0.0
    if ($trades -lt 8) {
        $tradePenalty = (8 - $trades) * 1.5
    }

    return [Math]::Round($balance + ($pf * 12.0) + $net - ($ddOver * 8.0) - $tradePenalty, 4)
}

function Parse-Override {
    param([string]$Item)

    $parts = $Item -split "=", 2
    if ($parts.Count -ne 2) {
        throw "Override invalido: '$Item'. Use Chave=Valor."
    }

    return @{
        Key = $parts[0].Trim()
        Value = $parts[1].Trim()
    }
}

function Set-SetValue {
    param(
        [string[]]$Lines,
        [string]$Key,
        [string]$Value
    )

    $found = $false
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -match "^(?<name>[^=]+)=(?<current>[^|]*)(?<rest>.*)$" -and $matches.name -eq $Key) {
            $Lines[$i] = "{0}={1}{2}" -f $Key, $Value, $matches.rest
            $found = $true
            break
        }
    }

    if (-not $found) {
        $Lines += "{0}={1}" -f $Key, $Value
    }

    return ,$Lines
}

function Write-SetFile {
    param(
        [string]$BaseSetFilePath,
        [string[]]$Overrides,
        [string]$TargetPath
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($line in [System.IO.File]::ReadAllLines($BaseSetFilePath)) {
        $null = $lines.Add($line)
    }

    foreach ($item in $Overrides) {
        $parsed = Parse-Override -Item $item
        $updated = Set-SetValue -Lines $lines.ToArray() -Key $parsed.Key -Value $parsed.Value
        $lines = [System.Collections.Generic.List[string]]::new()
        foreach ($line in $updated) {
            $null = $lines.Add($line)
        }
    }

    [System.IO.File]::WriteAllLines($TargetPath, $lines, [System.Text.Encoding]::ASCII)
}

function Invoke-Robocopy {
    param(
        [string]$SourcePath,
        [string]$DestinationPath,
        [string[]]$ExtraArgs = @()
    )

    $arguments = @(
        $SourcePath,
        $DestinationPath,
        "/MIR",
        "/R:1",
        "/W:1",
        "/NFL",
        "/NDL",
        "/NJH",
        "/NJS",
        "/NP"
    ) + $ExtraArgs

    $process = Start-Process -FilePath "robocopy.exe" `
        -ArgumentList $arguments `
        -Wait `
        -PassThru `
        -NoNewWindow

    if ($process.ExitCode -ge 8) {
        throw "robocopy falhou ao sincronizar '$SourcePath' -> '$DestinationPath' (exit code $($process.ExitCode))."
    }
}

function Prepare-PortableWorker {
    param(
        [string]$BasePortableRoot,
        [string]$WorkerRoot,
        [string]$BasesMode
    )

    $workerBases = Join-Path $WorkerRoot "bases"
    if (Test-Path $workerBases) {
        Remove-Item -Path $workerBases -Recurse -Force
    }

    New-Item -ItemType Directory -Force -Path $WorkerRoot | Out-Null
    Invoke-Robocopy `
        -SourcePath $BasePortableRoot `
        -DestinationPath $WorkerRoot `
        -ExtraArgs @(
            "/XD",
            (Join-Path $BasePortableRoot "logs"),
            (Join-Path $BasePortableRoot "reports"),
            (Join-Path $BasePortableRoot "bases")
        )

    $baseBases = Join-Path $BasePortableRoot "bases"
    if (-not (Test-Path $baseBases)) {
        throw "Nao encontrei a base de historico em '$baseBases'."
    }

    if ($BasesMode -eq "shared") {
        New-Item -ItemType Junction -Path $workerBases -Target $baseBases | Out-Null
        return
    }

    Invoke-Robocopy `
        -SourcePath $baseBases `
        -DestinationPath $workerBases
}

function New-WorkerPool {
    param(
        [string]$BasePortableRoot,
        [int]$RequestedWorkers,
        [int]$TaskCount,
        [string]$WorkersRootPath,
        [string]$BasesMode
    )

    $workerCount = [Math]::Min([Math]::Max(1, $RequestedWorkers), [Math]::Max(1, $TaskCount))
    $workersRootResolved = [System.IO.Path]::GetFullPath($WorkersRootPath)
    if ($workerCount -le 1) {
        return @([pscustomobject]@{
            name = "base"
            portable_root = $BasePortableRoot
            cloned = $false
        })
    }

    New-Item -ItemType Directory -Force -Path $workersRootResolved | Out-Null
    $workers = New-Object System.Collections.Generic.List[object]
    for ($i = 1; $i -le $workerCount; $i++) {
        $workerName = "worker-{0:d2}" -f $i
        $workerRoot = [System.IO.Path]::GetFullPath((Join-Path $workersRootResolved $workerName))
        Write-Host ("Preparando {0} em {1}" -f $workerName, $workerRoot)
        Prepare-PortableWorker `
            -BasePortableRoot $BasePortableRoot `
            -WorkerRoot $workerRoot `
            -BasesMode $BasesMode
        $workers.Add([pscustomobject]@{
            name = $workerName
            portable_root = $workerRoot
            cloned = $true
            bases_mode = $BasesMode
        }) | Out-Null
    }

    return $workers.ToArray()
}

function Invoke-WorkerWarmup {
    param(
        [object[]]$Workers,
        [string]$RunResearchPath,
        [string]$RunPrefixValue,
        [string]$ReportsDirectory,
        [string[]]$SymbolsList,
        [string]$CsvSuffixValue,
        [string]$WindowFrom,
        [string]$WindowTo,
        [int]$DepositValue,
        [int]$ExecutionModeValue
    )

    if ($Workers.Count -le 1 -and $Workers[0].name -eq "base") {
        return
    }

    foreach ($worker in $Workers) {
        $warmupRunName = "$RunPrefixValue.$($worker.name).warmup"
        Write-Host ("[warmup] {0} -> {1}" -f $worker.name, $warmupRunName)
        $json = & $RunResearchPath `
            -RunName $warmupRunName `
            -PortableRoot $worker.portable_root `
            -ReportsDir $ReportsDirectory `
            -Symbols $SymbolsList `
            -AssumeImportedHistory `
            -CsvSuffix $CsvSuffixValue `
            -SkipSingles `
            -FromDate $WindowFrom `
            -ToDate $WindowTo `
            -Deposit $DepositValue `
            -ExecutionMode $ExecutionModeValue `
            -OptimizationMode "single" `
            -OptimizationCriterion 6 `
            -ExtraOverride @(
                "InpEnableTelemetry=false",
                "InpEnableEvolutionExport=false",
                "InpEnableDedicatedSymbolAlphas=false"
            )

        $summary = $json | ConvertFrom-Json
        $portfolio = Get-PortfolioRun -Summary $summary
        if ($null -eq $portfolio -or [double]$portfolio.run.final_balance -le 0) {
            throw "Warmup falhou para '$($worker.name)'; o portfolio nao retornou balance valido."
        }

        Write-Host ("    [warmup] {0}: balance={1} dd={2}" -f `
            $worker.name, `
            $portfolio.run.final_balance, `
            $portfolio.run.equity_drawdown_raw)
    }
}

function Start-ResearchJob {
    param(
        [string]$RunResearchPath,
        [object]$Candidate,
        [string]$Phase,
        [string]$RunPrefixValue,
        [object]$Worker,
        [string]$ReportsDirectory,
        [string[]]$SymbolsList,
        [string]$CsvSuffixValue,
        [string]$WindowFrom,
        [string]$WindowTo,
        [int]$DepositValue,
        [int]$ExecutionModeValue,
        [string]$OptimizationModeValue,
        [int]$OptimizationCriterionValue
    )

    $runName = "$RunPrefixValue.$($Candidate.name).$Phase"
    $attempt = 1
    if ($Candidate.PSObject.Properties.Name -contains "attempt") {
        $attempt = [int]$Candidate.attempt
    }

    $job = Start-Job -Name "$Phase.$($Candidate.name).$($Worker.name).try$attempt" -ScriptBlock {
        param(
            [string]$NestedRunResearchPath,
            [string]$NestedRunName,
            [string]$NestedPortableRoot,
            [string]$NestedReportsDir,
            [string[]]$NestedSymbols,
            [string]$NestedCsvSuffix,
            [string[]]$NestedOverrides,
            [string]$NestedFromDate,
            [string]$NestedToDate,
            [int]$NestedDeposit,
            [int]$NestedExecutionMode,
            [string]$NestedOptimizationMode,
            [int]$NestedOptimizationCriterion
        )

        Set-StrictMode -Version Latest
        $ErrorActionPreference = "Stop"

        $json = & $NestedRunResearchPath `
            -RunName $NestedRunName `
            -PortableRoot $NestedPortableRoot `
            -ReportsDir $NestedReportsDir `
            -Symbols $NestedSymbols `
            -AssumeImportedHistory `
            -CsvSuffix $NestedCsvSuffix `
            -ExtraOverride $NestedOverrides `
            -SkipSingles `
            -FromDate $NestedFromDate `
            -ToDate $NestedToDate `
            -Deposit $NestedDeposit `
            -ExecutionMode $NestedExecutionMode `
            -OptimizationMode $NestedOptimizationMode `
            -OptimizationCriterion $NestedOptimizationCriterion

        [string]::Join("`n", @($json))
    } -ArgumentList @(
        $RunResearchPath,
        $runName,
        $Worker.portable_root,
        $ReportsDirectory,
        $SymbolsList,
        $CsvSuffixValue,
        $Candidate.overrides,
        $WindowFrom,
        $WindowTo,
        $DepositValue,
        $ExecutionModeValue,
        $OptimizationModeValue,
        $OptimizationCriterionValue
    )

    return [pscustomobject]@{
        job = $job
        candidate = $Candidate
        phase = $Phase
        worker = $Worker
        attempt = $attempt
        run_name = $runName
        from = $WindowFrom
        to = $WindowTo
    }
}

function Complete-ResearchJob {
    param([object]$JobMeta)

    try {
        $output = Receive-Job -Job $JobMeta.job -ErrorAction Stop
    }
    finally {
        Remove-Job -Job $JobMeta.job -Force | Out-Null
    }

    $json = [string]::Join("`n", @($output))
    if ([string]::IsNullOrWhiteSpace($json)) {
        throw "O job '$($JobMeta.run_name)' nao retornou JSON."
    }

    $summary = $json | ConvertFrom-Json
    $portfolio = Get-PortfolioRun -Summary $summary
    if ($null -eq $portfolio) {
        throw "Nao encontrei run de portfolio para '$($JobMeta.candidate.name)' na fase '$($JobMeta.phase)'."
    }

    $equityDdPct = Get-DrawdownPercent -RawValue $portfolio.run.equity_drawdown_raw
    $score = Score-PortfolioRun -Run $portfolio.run

    Write-Host ("    [{0}] {1} em {2}: balance={3} pf={4} dd={5}% trades={6} score={7}" -f `
        $JobMeta.phase, `
        $JobMeta.candidate.name, `
        $JobMeta.worker.name, `
        $portfolio.run.final_balance, `
        $portfolio.run.profit_factor, `
        $equityDdPct, `
        $portfolio.run.total_trades, `
        $score)

    return [pscustomobject]@{
        phase = $JobMeta.phase
        profile = $JobMeta.candidate.name
        attempt = $JobMeta.attempt
        score = $score
        overrides = $JobMeta.candidate.overrides
        from = $JobMeta.from
        to = $JobMeta.to
        final_balance = [double]$portfolio.run.final_balance
        total_net_profit = [double]$portfolio.run.total_net_profit
        profit_factor = [double]$portfolio.run.profit_factor
        total_trades = [int]$portfolio.run.total_trades
        equity_drawdown_pct = $equityDdPct
        equity_drawdown_raw = $portfolio.run.equity_drawdown_raw
        report_path = $portfolio.run.report_path
        worker_name = $JobMeta.worker.name
        worker_portable_root = $JobMeta.worker.portable_root
        summary = $summary
    }
}

function Invoke-ResearchPhase {
    param(
        [string]$Phase,
        [object[]]$Candidates,
        [object[]]$Workers,
        [string]$RunResearchPath,
        [string]$RunPrefixValue,
        [string]$ReportsDirectory,
        [string[]]$SymbolsList,
        [string]$CsvSuffixValue,
        [string]$WindowFrom,
        [string]$WindowTo,
        [int]$DepositValue,
        [int]$ExecutionModeValue,
        [string]$OptimizationModeValue,
        [int]$OptimizationCriterionValue
    )

    $results = New-Object System.Collections.Generic.List[object]
    if ($Candidates.Count -eq 0) {
        return $results
    }

    $queue = [System.Collections.Generic.Queue[object]]::new()
    foreach ($candidate in $Candidates) {
        $attempt = 1
        if ($candidate.PSObject.Properties.Name -contains "attempt") {
            $attempt = [int]$candidate.attempt
        }

        $queue.Enqueue([pscustomobject]@{
            name = $candidate.name
            overrides = $candidate.overrides
            attempt = $attempt
        })
    }

    $running = New-Object System.Collections.Generic.List[object]
    while ($queue.Count -gt 0 -or $running.Count -gt 0) {
        while ($queue.Count -gt 0 -and $running.Count -lt $Workers.Count) {
            $busyWorkers = @($running | ForEach-Object { $_.worker.name })
            $worker = $Workers |
                Where-Object { $busyWorkers -notcontains $_.name } |
                Select-Object -First 1
            if ($null -eq $worker) {
                break
            }

            $candidate = $queue.Dequeue()
            Write-Host ("[queue {0}] {1} -> {2}" -f $Phase, $candidate.name, $worker.name)
            $jobMeta = Start-ResearchJob `
                -RunResearchPath $RunResearchPath `
                -Candidate $candidate `
                -Phase $Phase `
                -RunPrefixValue $RunPrefixValue `
                -Worker $worker `
                -ReportsDirectory $ReportsDirectory `
                -SymbolsList $SymbolsList `
                -CsvSuffixValue $CsvSuffixValue `
                -WindowFrom $WindowFrom `
                -WindowTo $WindowTo `
                -DepositValue $DepositValue `
                -ExecutionModeValue $ExecutionModeValue `
                -OptimizationModeValue $OptimizationModeValue `
                -OptimizationCriterionValue $OptimizationCriterionValue
            $running.Add($jobMeta) | Out-Null
        }

        if ($running.Count -eq 0) {
            continue
        }

        $finishedJob = Wait-Job -Job ($running | ForEach-Object { $_.job }) -Any
        $jobMeta = $running | Where-Object { $_.job.Id -eq $finishedJob.Id } | Select-Object -First 1
        $completed = Complete-ResearchJob -JobMeta $jobMeta
        if ($completed.final_balance -le 0 -and $jobMeta.attempt -lt 2) {
            Write-Host ("    [{0}] {1} em {2}: resultado invalido, reenfileirando tentativa {3}" -f `
                $jobMeta.phase, `
                $jobMeta.candidate.name, `
                $jobMeta.worker.name, `
                ($jobMeta.attempt + 1))
            $queue.Enqueue([pscustomobject]@{
                name = $jobMeta.candidate.name
                overrides = $jobMeta.candidate.overrides
                attempt = ($jobMeta.attempt + 1)
            })
        }
        else {
            $results.Add($completed) | Out-Null
        }
        [void]$running.Remove($jobMeta)
    }

    return $results
}

$portableResolved = (Resolve-Path $PortableRoot).Path
$Symbols = Expand-SymbolList -InputSymbols $Symbols
$runResearch = Join-Path $PSScriptRoot "Run-AplexFlowResearch.ps1"
$importFolder = Join-Path $PSScriptRoot "Import-HistoricalFolder.ps1"
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $PSScriptRoot ("..\reports\{0}.results.json" -f $RunPrefix)
}
$reportsDir = Split-Path $OutputPath -Parent

if (-not (Test-Path $reportsDir)) {
    New-Item -Path $reportsDir -ItemType Directory | Out-Null
}

if ($EnsureImportedHistory) {
    Write-Host "Importando/confirmando historico customizado..."
    & $importFolder `
        -HistoryFolder $HistoryFolder `
        -PortableRoot $portableResolved `
        -Symbols $Symbols `
        -Suffix $CsvSuffix | Out-Null
}

if ($OptimizationMode -ne "single" -and $MaxParallel -gt 1) {
    throw "Use MaxParallel=1 quando OptimizationMode for diferente de 'single' para evitar oversubscription dos agentes."
}

if ($ProfileMode -eq "refine") {
    $profiles = @(
        [pscustomobject]@{
            name = "edge69_low_risk"
            overrides = @(
                "InpEdgeThreshold=0.69",
                "InpHardBlockThreshold=0.55",
                "InpEnableMeanReversion=false",
                "InpMaxPortfolioRiskPct=3.0",
                "InpMaxPerSymbolRiskPct=1.5",
                "InpMaxPositions=3",
                "InpMaxClusterEntries=2",
                "InpMaxDailyLossPct=2.0",
                "InpTrailStartR=1.80",
                "InpTrailStepAtr=0.10"
            )
        },
        [pscustomobject]@{
            name = "edge69_sym5_pf85"
            overrides = @(
                "InpEdgeThreshold=0.69",
                "InpHardBlockThreshold=0.55",
                "InpEnableMeanReversion=false",
                "InpMaxPortfolioRiskPct=3.0",
                "InpMaxPerSymbolRiskPct=1.5",
                "InpMaxPositions=3",
                "InpMaxClusterEntries=2",
                "InpMaxDailyLossPct=2.0",
                "InpTrailStartR=1.80",
                "InpTrailStepAtr=0.10",
                "InpSymbolDegradationWindow=5",
                "InpMinSymbolExpectancyR=-0.04",
                "InpSymbolMinProfitFactor=0.85",
                "InpSymbolCooldownMinutes=480"
            )
        },
        [pscustomobject]@{
            name = "edge69_sym5_pf90"
            overrides = @(
                "InpEdgeThreshold=0.69",
                "InpHardBlockThreshold=0.55",
                "InpEnableMeanReversion=false",
                "InpMaxPortfolioRiskPct=3.0",
                "InpMaxPerSymbolRiskPct=1.5",
                "InpMaxPositions=3",
                "InpMaxClusterEntries=2",
                "InpMaxDailyLossPct=2.0",
                "InpTrailStartR=1.80",
                "InpTrailStepAtr=0.10",
                "InpSymbolDegradationWindow=5",
                "InpMinSymbolExpectancyR=-0.03",
                "InpSymbolMinProfitFactor=0.90",
                "InpSymbolCooldownMinutes=480"
            )
        },
        [pscustomobject]@{
            name = "edge69_sym4_pf90"
            overrides = @(
                "InpEdgeThreshold=0.69",
                "InpHardBlockThreshold=0.55",
                "InpEnableMeanReversion=false",
                "InpMaxPortfolioRiskPct=3.0",
                "InpMaxPerSymbolRiskPct=1.5",
                "InpMaxPositions=3",
                "InpMaxClusterEntries=2",
                "InpMaxDailyLossPct=2.0",
                "InpTrailStartR=1.80",
                "InpTrailStepAtr=0.10",
                "InpSymbolDegradationWindow=4",
                "InpMinSymbolExpectancyR=-0.03",
                "InpSymbolMinProfitFactor=0.90",
                "InpSymbolCooldownMinutes=480"
            )
        },
        [pscustomobject]@{
            name = "edge68_sym5_pf85"
            overrides = @(
                "InpEdgeThreshold=0.68",
                "InpHardBlockThreshold=0.54",
                "InpEnableMeanReversion=false",
                "InpMaxPortfolioRiskPct=3.0",
                "InpMaxPerSymbolRiskPct=1.5",
                "InpMaxPositions=3",
                "InpMaxClusterEntries=2",
                "InpMaxDailyLossPct=2.0",
                "InpTrailStartR=1.80",
                "InpTrailStepAtr=0.10",
                "InpSymbolDegradationWindow=5",
                "InpMinSymbolExpectancyR=-0.04",
                "InpSymbolMinProfitFactor=0.85",
                "InpSymbolCooldownMinutes=480"
            )
        }
    )
}
elseif ($ProfileMode -eq "dedicated") {
    $profiles = @(
        [pscustomobject]@{
            name = "us500_only_robust"
            overrides = @(
                "InpEnableDedicatedSymbolAlphas=true",
                "InpEnableDedicatedXauAlpha=false",
                "InpEnableDedicatedUs500Alpha=true",
                "InpEnableMeanReversion=false",
                "InpEdgeThreshold=0.69",
                "InpHardBlockThreshold=0.55",
                "InpMaxPortfolioRiskPct=3.0",
                "InpMaxPerSymbolRiskPct=1.45",
                "InpMaxPositions=3",
                "InpMaxClusterEntries=2",
                "InpMaxDailyLossPct=2.0",
                "InpTrailStartR=1.80",
                "InpTrailStepAtr=0.10",
                "InpSymbolDegradationWindow=5",
                "InpMinSymbolExpectancyR=-0.03",
                "InpSymbolMinProfitFactor=0.90",
                "InpSymbolCooldownMinutes=480"
            )
        },
        [pscustomobject]@{
            name = "us500_only_balanced"
            overrides = @(
                "InpEnableDedicatedSymbolAlphas=true",
                "InpEnableDedicatedXauAlpha=false",
                "InpEnableDedicatedUs500Alpha=true",
                "InpEnableMeanReversion=false",
                "InpEdgeThreshold=0.68",
                "InpHardBlockThreshold=0.54",
                "InpMaxPortfolioRiskPct=3.4",
                "InpMaxPerSymbolRiskPct=1.60",
                "InpMaxPositions=4",
                "InpMaxClusterEntries=2",
                "InpMaxDailyLossPct=2.2",
                "InpTrailStartR=1.75",
                "InpTrailStepAtr=0.09",
                "InpSymbolDegradationWindow=5",
                "InpMinSymbolExpectancyR=-0.04",
                "InpSymbolMinProfitFactor=0.85",
                "InpSymbolCooldownMinutes=420"
            )
        },
        [pscustomobject]@{
            name = "us500_only_aggressive"
            overrides = @(
                "InpEnableDedicatedSymbolAlphas=true",
                "InpEnableDedicatedXauAlpha=false",
                "InpEnableDedicatedUs500Alpha=true",
                "InpEnableMeanReversion=false",
                "InpEdgeThreshold=0.66",
                "InpHardBlockThreshold=0.53",
                "InpMaxPortfolioRiskPct=4.2",
                "InpMaxPerSymbolRiskPct=2.0",
                "InpMaxPositions=4",
                "InpMaxClusterEntries=2",
                "InpMaxDailyLossPct=2.7",
                "InpTrailStartR=1.60",
                "InpTrailStepAtr=0.08",
                "InpSymbolDegradationWindow=4",
                "InpMinSymbolExpectancyR=-0.05",
                "InpSymbolMinProfitFactor=0.82",
                "InpSymbolCooldownMinutes=360"
            )
        },
        [pscustomobject]@{
            name = "xau_us500_combo"
            overrides = @(
                "InpEnableDedicatedSymbolAlphas=true",
                "InpEnableDedicatedXauAlpha=true",
                "InpEnableDedicatedUs500Alpha=true",
                "InpEnableMeanReversion=false",
                "InpEdgeThreshold=0.68",
                "InpHardBlockThreshold=0.54",
                "InpMaxPortfolioRiskPct=3.2",
                "InpMaxPerSymbolRiskPct=1.55",
                "InpMaxPositions=3",
                "InpMaxClusterEntries=2",
                "InpMaxDailyLossPct=2.0",
                "InpTrailStartR=1.80",
                "InpTrailStepAtr=0.10",
                "InpSymbolDegradationWindow=5",
                "InpMinSymbolExpectancyR=-0.03",
                "InpSymbolMinProfitFactor=0.88",
                "InpSymbolCooldownMinutes=480"
            )
        }
    )
}
elseif ($ProfileMode -eq "frontier") {
    $profiles = @(
        [pscustomobject]@{
            name = "carrier_combo_anchor"
            overrides = @(
                "InpEnableDedicatedSymbolAlphas=true",
                "InpEnableDedicatedXauAlpha=true",
                "InpEnableDedicatedUs500Alpha=true",
                "InpEnableMeanReversion=false",
                "InpEdgeThreshold=0.68",
                "InpHardBlockThreshold=0.54",
                "InpMaxPortfolioRiskPct=3.2",
                "InpMaxPerSymbolRiskPct=1.55",
                "InpMaxPositions=3",
                "InpMaxClusterEntries=2",
                "InpMaxTradesPerDayPerSymbol=3",
                "InpMaxDailyLossPct=2.0",
                "InpTrailStartR=1.80",
                "InpTrailStepAtr=0.10",
                "InpTp3R=4.2",
                "InpSymbolDegradationWindow=5",
                "InpMinSymbolExpectancyR=-0.03",
                "InpSymbolMinProfitFactor=0.88",
                "InpSymbolCooldownMinutes=480"
            )
        },
        [pscustomobject]@{
            name = "carrier_combo_flow"
            overrides = @(
                "InpEnableDedicatedSymbolAlphas=true",
                "InpEnableDedicatedXauAlpha=true",
                "InpEnableDedicatedUs500Alpha=true",
                "InpEnableMeanReversion=false",
                "InpEdgeThreshold=0.67",
                "InpHardBlockThreshold=0.54",
                "InpMaxPortfolioRiskPct=3.35",
                "InpMaxPerSymbolRiskPct=1.60",
                "InpMaxPositions=4",
                "InpMaxClusterEntries=2",
                "InpMaxTradesPerDayPerSymbol=4",
                "InpMaxDailyLossPct=2.1",
                "InpTrailStartR=1.72",
                "InpTrailStepAtr=0.09",
                "InpTp3R=4.5",
                "InpSymbolDegradationWindow=5",
                "InpMinSymbolExpectancyR=-0.04",
                "InpSymbolMinProfitFactor=0.86",
                "InpSymbolCooldownMinutes=360"
            )
        },
        [pscustomobject]@{
            name = "carrier_combo_runner"
            overrides = @(
                "InpEnableDedicatedSymbolAlphas=true",
                "InpEnableDedicatedXauAlpha=true",
                "InpEnableDedicatedUs500Alpha=true",
                "InpEnableMeanReversion=false",
                "InpEdgeThreshold=0.67",
                "InpHardBlockThreshold=0.53",
                "InpMaxPortfolioRiskPct=3.4",
                "InpMaxPerSymbolRiskPct=1.62",
                "InpMaxPositions=4",
                "InpMaxClusterEntries=2",
                "InpMaxTradesPerDayPerSymbol=4",
                "InpMaxDailyLossPct=2.2",
                "InpBreakEvenAtR=0.70",
                "InpTrailStartR=1.90",
                "InpTrailAtrMult=1.20",
                "InpTrailStepAtr=0.11",
                "InpTp3R=5.0",
                "InpSymbolDegradationWindow=5",
                "InpMinSymbolExpectancyR=-0.04",
                "InpSymbolMinProfitFactor=0.86",
                "InpSymbolCooldownMinutes=360"
            )
        },
        [pscustomobject]@{
            name = "carrier_combo_push"
            overrides = @(
                "InpEnableDedicatedSymbolAlphas=true",
                "InpEnableDedicatedXauAlpha=true",
                "InpEnableDedicatedUs500Alpha=true",
                "InpEnableMeanReversion=false",
                "InpEdgeThreshold=0.66",
                "InpHardBlockThreshold=0.53",
                "InpMaxPortfolioRiskPct=3.55",
                "InpMaxPerSymbolRiskPct=1.70",
                "InpMaxPositions=4",
                "InpMaxClusterEntries=2",
                "InpMaxTradesPerDayPerSymbol=4",
                "InpMaxDailyLossPct=2.3",
                "InpBreakEvenAtR=0.68",
                "InpTrailStartR=1.65",
                "InpTrailStepAtr=0.08",
                "InpTp3R=4.8",
                "InpSymbolDegradationWindow=4",
                "InpMinSymbolExpectancyR=-0.05",
                "InpSymbolMinProfitFactor=0.84",
                "InpSymbolCooldownMinutes=300"
            )
        },
        [pscustomobject]@{
            name = "carrier_combo_tight"
            overrides = @(
                "InpEnableDedicatedSymbolAlphas=true",
                "InpEnableDedicatedXauAlpha=true",
                "InpEnableDedicatedUs500Alpha=true",
                "InpEnableMeanReversion=false",
                "InpEdgeThreshold=0.69",
                "InpHardBlockThreshold=0.55",
                "InpMaxPortfolioRiskPct=3.1",
                "InpMaxPerSymbolRiskPct=1.50",
                "InpMaxPositions=3",
                "InpMaxClusterEntries=2",
                "InpMaxTradesPerDayPerSymbol=3",
                "InpMaxDailyLossPct=1.9",
                "InpBreakEvenAtR=0.72",
                "InpTrailStartR=1.82",
                "InpTrailStepAtr=0.10",
                "InpTp3R=4.4",
                "InpSymbolDegradationWindow=5",
                "InpMinSymbolExpectancyR=-0.02",
                "InpSymbolMinProfitFactor=0.90",
                "InpSymbolCooldownMinutes=480"
            )
        },
        [pscustomobject]@{
            name = "carrier_combo_cluster3"
            overrides = @(
                "InpEnableDedicatedSymbolAlphas=true",
                "InpEnableDedicatedXauAlpha=true",
                "InpEnableDedicatedUs500Alpha=true",
                "InpEnableMeanReversion=false",
                "InpEdgeThreshold=0.67",
                "InpHardBlockThreshold=0.53",
                "InpMaxPortfolioRiskPct=3.45",
                "InpMaxPerSymbolRiskPct=1.60",
                "InpMaxPositions=4",
                "InpMaxClusterEntries=3",
                "InpMaxTradesPerDayPerSymbol=4",
                "InpMaxDailyLossPct=2.2",
                "InpBreakEvenAtR=0.70",
                "InpTrailStartR=1.78",
                "InpTrailStepAtr=0.09",
                "InpTp3R=4.8",
                "InpSymbolDegradationWindow=4",
                "InpMinSymbolExpectancyR=-0.04",
                "InpSymbolMinProfitFactor=0.85",
                "InpSymbolCooldownMinutes=300"
            )
        },
        [pscustomobject]@{
            name = "us500_bias_carrier"
            overrides = @(
                "InpEnableDedicatedSymbolAlphas=true",
                "InpEnableDedicatedXauAlpha=false",
                "InpEnableDedicatedUs500Alpha=true",
                "InpEnableMeanReversion=false",
                "InpEdgeThreshold=0.68",
                "InpHardBlockThreshold=0.54",
                "InpMaxPortfolioRiskPct=3.3",
                "InpMaxPerSymbolRiskPct=1.60",
                "InpMaxPositions=4",
                "InpMaxClusterEntries=2",
                "InpMaxTradesPerDayPerSymbol=4",
                "InpMaxDailyLossPct=2.1",
                "InpBreakEvenAtR=0.70",
                "InpTrailStartR=1.72",
                "InpTrailStepAtr=0.09",
                "InpTp3R=4.5",
                "InpSymbolDegradationWindow=5",
                "InpMinSymbolExpectancyR=-0.04",
                "InpSymbolMinProfitFactor=0.86",
                "InpSymbolCooldownMinutes=360"
            )
        },
        [pscustomobject]@{
            name = "xau_bias_carrier"
            overrides = @(
                "InpEnableDedicatedSymbolAlphas=true",
                "InpEnableDedicatedXauAlpha=true",
                "InpEnableDedicatedUs500Alpha=false",
                "InpEnableMeanReversion=false",
                "InpEdgeThreshold=0.68",
                "InpHardBlockThreshold=0.54",
                "InpMaxPortfolioRiskPct=3.3",
                "InpMaxPerSymbolRiskPct=1.60",
                "InpMaxPositions=4",
                "InpMaxClusterEntries=2",
                "InpMaxTradesPerDayPerSymbol=4",
                "InpMaxDailyLossPct=2.1",
                "InpBreakEvenAtR=0.70",
                "InpTrailStartR=1.78",
                "InpTrailStepAtr=0.09",
                "InpTp3R=4.8",
                "InpSymbolDegradationWindow=5",
                "InpMinSymbolExpectancyR=-0.04",
                "InpSymbolMinProfitFactor=0.86",
                "InpSymbolCooldownMinutes=360"
            )
        },
        [pscustomobject]@{
            name = "carrier_combo_meanrev_probe"
            overrides = @(
                "InpEnableDedicatedSymbolAlphas=true",
                "InpEnableDedicatedXauAlpha=true",
                "InpEnableDedicatedUs500Alpha=true",
                "InpEnableMeanReversion=true",
                "InpEdgeThreshold=0.69",
                "InpHardBlockThreshold=0.55",
                "InpMaxPortfolioRiskPct=3.0",
                "InpMaxPerSymbolRiskPct=1.45",
                "InpMaxPositions=3",
                "InpMaxClusterEntries=2",
                "InpMaxTradesPerDayPerSymbol=3",
                "InpMaxDailyLossPct=1.9",
                "InpBreakEvenAtR=0.72",
                "InpTrailStartR=1.85",
                "InpTrailStepAtr=0.10",
                "InpTp3R=4.2",
                "InpSymbolDegradationWindow=5",
                "InpMinSymbolExpectancyR=-0.03",
                "InpSymbolMinProfitFactor=0.88",
                "InpSymbolCooldownMinutes=420"
            )
        },
        [pscustomobject]@{
            name = "carrier_combo_breakeven_fast"
            overrides = @(
                "InpEnableDedicatedSymbolAlphas=true",
                "InpEnableDedicatedXauAlpha=true",
                "InpEnableDedicatedUs500Alpha=true",
                "InpEnableMeanReversion=false",
                "InpEdgeThreshold=0.67",
                "InpHardBlockThreshold=0.53",
                "InpMaxPortfolioRiskPct=3.35",
                "InpMaxPerSymbolRiskPct=1.60",
                "InpMaxPositions=4",
                "InpMaxClusterEntries=2",
                "InpMaxTradesPerDayPerSymbol=4",
                "InpMaxDailyLossPct=2.2",
                "InpBreakEvenAtR=0.60",
                "InpTrailStartR=1.55",
                "InpTrailStepAtr=0.08",
                "InpTp3R=4.6",
                "InpSymbolDegradationWindow=4",
                "InpMinSymbolExpectancyR=-0.05",
                "InpSymbolMinProfitFactor=0.84",
                "InpSymbolCooldownMinutes=300"
            )
        },
        [pscustomobject]@{
            name = "carrier_combo_corr_relax"
            overrides = @(
                "InpEnableDedicatedSymbolAlphas=true",
                "InpEnableDedicatedXauAlpha=true",
                "InpEnableDedicatedUs500Alpha=true",
                "InpEnableMeanReversion=false",
                "InpEdgeThreshold=0.67",
                "InpHardBlockThreshold=0.53",
                "InpMaxPortfolioRiskPct=3.45",
                "InpMaxPerSymbolRiskPct=1.65",
                "InpMaxPositions=4",
                "InpMaxClusterEntries=2",
                "InpMaxTradesPerDayPerSymbol=4",
                "InpMaxDailyLossPct=2.2",
                "InpEnableCorrelationHardBlock=false",
                "InpBreakEvenAtR=0.68",
                "InpTrailStartR=1.70",
                "InpTrailStepAtr=0.08",
                "InpTp3R=4.8",
                "InpSymbolDegradationWindow=4",
                "InpMinSymbolExpectancyR=-0.05",
                "InpSymbolMinProfitFactor=0.84",
                "InpSymbolCooldownMinutes=300"
            )
        },
        [pscustomobject]@{
            name = "carrier_combo_momentum"
            overrides = @(
                "InpEnableDedicatedSymbolAlphas=true",
                "InpEnableDedicatedXauAlpha=true",
                "InpEnableDedicatedUs500Alpha=true",
                "InpEnableMeanReversion=false",
                "InpEnableSweep=false",
                "InpEdgeThreshold=0.66",
                "InpHardBlockThreshold=0.53",
                "InpMaxPortfolioRiskPct=3.5",
                "InpMaxPerSymbolRiskPct=1.65",
                "InpMaxPositions=4",
                "InpMaxClusterEntries=2",
                "InpMaxTradesPerDayPerSymbol=4",
                "InpMaxDailyLossPct=2.2",
                "InpBreakEvenAtR=0.68",
                "InpTrailStartR=1.65",
                "InpTrailStepAtr=0.08",
                "InpTp3R=5.0",
                "InpSymbolDegradationWindow=4",
                "InpMinSymbolExpectancyR=-0.05",
                "InpSymbolMinProfitFactor=0.84",
                "InpSymbolCooldownMinutes=300"
            )
        }
    )
}
else {
    $profiles = @(
        [pscustomobject]@{
            name = "baseline"
            overrides = @()
        },
        [pscustomobject]@{
            name = "edge66_no_mrv"
            overrides = @(
                "InpEdgeThreshold=0.66",
                "InpHardBlockThreshold=0.52",
                "InpEnableMeanReversion=false"
            )
        },
        [pscustomobject]@{
            name = "edge66_no_sweep"
            overrides = @(
                "InpEdgeThreshold=0.66",
                "InpHardBlockThreshold=0.52",
                "InpEnableSweep=false"
            )
        },
        [pscustomobject]@{
            name = "edge68_no_mrv"
            overrides = @(
                "InpEdgeThreshold=0.68",
                "InpHardBlockThreshold=0.54",
                "InpEnableMeanReversion=false"
            )
        },
        [pscustomobject]@{
            name = "edge68_low_risk"
            overrides = @(
                "InpEdgeThreshold=0.68",
                "InpHardBlockThreshold=0.54",
                "InpEnableMeanReversion=false",
                "InpMaxPortfolioRiskPct=3.0",
                "InpMaxPerSymbolRiskPct=1.5",
                "InpMaxPositions=3",
                "InpMaxClusterEntries=2",
                "InpMaxDailyLossPct=2.0",
                "InpTrailStartR=1.80",
                "InpTrailStepAtr=0.10"
            )
        },
        [pscustomobject]@{
            name = "trend_core"
            overrides = @(
                "InpEdgeThreshold=0.66",
                "InpHardBlockThreshold=0.54",
                "InpEnableMeanReversion=false",
                "InpEnableSweep=false",
                "InpMaxPortfolioRiskPct=3.0",
                "InpMaxPerSymbolRiskPct=1.5",
                "InpMaxPositions=3",
                "InpMaxClusterEntries=2",
                "InpMaxDailyLossPct=2.0",
                "InpMaxTradesPerDayPerSymbol=2",
                "InpTrailStartR=1.80",
                "InpTrailStepAtr=0.10"
            )
        }
    )
}

$workers = New-WorkerPool `
    -BasePortableRoot $portableResolved `
    -RequestedWorkers $MaxParallel `
    -TaskCount $profiles.Count `
    -WorkersRootPath $WorkersRoot `
    -BasesMode $WorkerBasesMode

if ($PrimeWorkers) {
    Invoke-WorkerWarmup `
        -Workers $workers `
        -RunResearchPath $runResearch `
        -RunPrefixValue $RunPrefix `
        -ReportsDirectory $reportsDir `
        -SymbolsList $Symbols `
        -CsvSuffixValue $CsvSuffix `
        -WindowFrom $TrainFromDate `
        -WindowTo $TrainToDate `
        -DepositValue $Deposit `
        -ExecutionModeValue $ExecutionMode
}

$trainResults = Invoke-ResearchPhase `
    -Phase "train" `
    -Candidates $profiles `
    -Workers $workers `
    -RunResearchPath $runResearch `
    -RunPrefixValue $RunPrefix `
    -ReportsDirectory $reportsDir `
    -SymbolsList $Symbols `
    -CsvSuffixValue $CsvSuffix `
    -WindowFrom $TrainFromDate `
    -WindowTo $TrainToDate `
    -DepositValue $Deposit `
    -ExecutionModeValue $ExecutionMode `
    -OptimizationModeValue $OptimizationMode `
    -OptimizationCriterionValue $OptimizationCriterion

$rankedTrain = $trainResults | Sort-Object score -Descending
$validateCount = [Math]::Min($TopToValidate, $rankedTrain.Count)
$validationCandidates = @()
for ($i = 0; $i -lt $validateCount; $i++) {
    $candidate = $rankedTrain[$i]
    $validationCandidates += [pscustomobject]@{
        name = $candidate.profile
        overrides = $candidate.overrides
    }
}

$validationResults = Invoke-ResearchPhase `
    -Phase "validate" `
    -Candidates $validationCandidates `
    -Workers $workers `
    -RunResearchPath $runResearch `
    -RunPrefixValue $RunPrefix `
    -ReportsDirectory $reportsDir `
    -SymbolsList $Symbols `
    -CsvSuffixValue $CsvSuffix `
    -WindowFrom $ValidateFromDate `
    -WindowTo $ValidateToDate `
    -DepositValue $Deposit `
    -ExecutionModeValue $ExecutionMode `
    -OptimizationModeValue $OptimizationMode `
    -OptimizationCriterionValue $OptimizationCriterion

$bestValidated = $validationResults | Sort-Object score -Descending | Select-Object -First 1
$bestSetPath = $null

if ($null -ne $bestValidated) {
    $bestSetPath = Join-Path $reportsDir "$RunPrefix.best.set"
    $bestSetOverrides = @(
        "InpSymbols=$($Symbols -join ',')",
        "InpBacktestLatencyMs=$ExecutionMode"
    ) + $bestValidated.overrides
    Write-SetFile -BaseSetFilePath (Resolve-Path $BaseSetFile).Path -Overrides $bestSetOverrides -TargetPath $bestSetPath
}

$payload = [pscustomobject]@{
    run_prefix = $RunPrefix
    portable_root = $portableResolved
    max_parallel = $MaxParallel
    workers = $workers
    optimization_mode = $OptimizationMode
    optimization_criterion = $OptimizationCriterion
    train_window = @{
        from = $TrainFromDate
        to = $TrainToDate
    }
    validation_window = @{
        from = $ValidateFromDate
        to = $ValidateToDate
    }
    profiles = $profiles
    ranked_train = $rankedTrain
    validation = $validationResults
    best_validated = $bestValidated
    best_set_path = $bestSetPath
}

$payload | ConvertTo-Json -Depth 8 | Set-Content -Path $OutputPath -Encoding ASCII
$payload | ConvertTo-Json -Depth 8
