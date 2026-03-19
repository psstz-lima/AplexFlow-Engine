param(
    [double[]]$BreakEvenAtrTrigger = @(0.55, 0.80, 1.05),
    [int[]]$BreakEvenOffsetPoints = @(10, 20),
    [double[]]$TrailStartAtr = @(0.90, 1.20, 1.50),
    [double[]]$TrailAtrMult = @(1.30, 1.60, 1.90),
    [string]$PortableSource = (Join-Path $PSScriptRoot "..\..\mt5-portable\MQL5\Experts\AplexFlow\AplexFlow_Engine.mq5"),
    [string]$PortableMetaEditor = (Join-Path $PSScriptRoot "..\..\mt5-portable\MetaEditor64.exe"),
    [string]$OutputPath = (Join-Path $PSScriptRoot "..\..\mt5-portable\reports\m5_exit_tuning.json")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function To-InvariantString {
    param([double]$Value)
    return $Value.ToString([System.Globalization.CultureInfo]::InvariantCulture)
}

function To-Token {
    param([double]$Value)
    return (To-InvariantString $Value).Replace(".", "p")
}

function Set-M5ExitParams {
    param(
        [string]$SourceText,
        [double]$BeTrigger,
        [int]$BeOffset,
        [double]$TrailStart,
        [double]$TrailMult
    )

    $lines = $SourceText -split "`r?`n"
    $inM5Block = $false

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $trimmed = $lines[$i].Trim()

        if ($trimmed -eq 'case CFG_XAUUSD_M5_RBFX_STD:') {
            $inM5Block = $true
            continue
        }

        if (-not $inM5Block) {
            continue
        }

        if ($trimmed.StartsWith('params.breakEvenAtrTrigger =')) {
            $lines[$i] = '         params.breakEvenAtrTrigger = ' + (To-InvariantString $BeTrigger) + ';'
            continue
        }

        if ($trimmed.StartsWith('params.breakEvenOffsetPoints =')) {
            $lines[$i] = '         params.breakEvenOffsetPoints = ' + $BeOffset + ';'
            continue
        }

        if ($trimmed.StartsWith('params.trailStartAtr =')) {
            $lines[$i] = '         params.trailStartAtr = ' + (To-InvariantString $TrailStart) + ';'
            continue
        }

        if ($trimmed.StartsWith('params.trailAtrMult =')) {
            $lines[$i] = '         params.trailAtrMult = ' + (To-InvariantString $TrailMult) + ';'
            continue
        }

        if ($trimmed -eq 'break;' -and $inM5Block) {
            break
        }
    }

    return ($lines -join "`r`n")
}

$portableSourceResolved = (Resolve-Path $PortableSource).Path
$portableMetaEditorResolved = (Resolve-Path $PortableMetaEditor).Path
$runScript = Join-Path $PSScriptRoot "..\Run-Mt5Backtest.ps1"
$portableRoot = Split-Path (Split-Path (Split-Path (Split-Path $portableSourceResolved -Parent) -Parent) -Parent) -Parent

if (-not (Test-Path $runScript)) {
    throw "Nao encontrei o runner em '$runScript'."
}

$originalText = Get-Content -Path $portableSourceResolved -Raw -Encoding UTF8
$results = [System.Collections.Generic.List[object]]::new()
$totalRuns = $BreakEvenAtrTrigger.Count * $BreakEvenOffsetPoints.Count * $TrailStartAtr.Count * $TrailAtrMult.Count
$runIndex = 0

try {
    foreach ($beTrigger in $BreakEvenAtrTrigger) {
        foreach ($beOffset in $BreakEvenOffsetPoints) {
            foreach ($trailStart in $TrailStartAtr) {
                foreach ($trailMult in $TrailAtrMult) {
                    $runIndex++
                    $runName = "m5exit_be{0}_off{1}_ts{2}_td{3}" -f `
                        (To-Token $beTrigger), `
                        $beOffset, `
                        (To-Token $trailStart), `
                        (To-Token $trailMult)

                    $updatedText = Set-M5ExitParams -SourceText $originalText `
                        -BeTrigger $beTrigger `
                        -BeOffset $beOffset `
                        -TrailStart $trailStart `
                        -TrailMult $trailMult

                    Set-Content -Path $portableSourceResolved -Value $updatedText -Encoding UTF8

                    $compileLog = Join-Path $portableRoot ("compile_{0}.log" -f $runName)
                    $proc = Start-Process -FilePath $portableMetaEditorResolved `
                        -ArgumentList @('/portable', "/compile:$portableSourceResolved", "/log:$compileLog") `
                        -Wait `
                        -PassThru
                    if ($proc.ExitCode -ne 1) {
                        throw "Compilacao falhou para '$runName' com exit code $($proc.ExitCode)."
                    }

                    $result = & $runScript -RunName $runName -Override @('InpTradingMode=0', 'InpConfigTemplate=2') | ConvertFrom-Json
                    $null = $result | Add-Member -NotePropertyName break_even_atr_trigger -NotePropertyValue $beTrigger -PassThru |
                        Add-Member -NotePropertyName break_even_offset_points -NotePropertyValue $beOffset -PassThru |
                        Add-Member -NotePropertyName trail_start_atr -NotePropertyValue $trailStart -PassThru |
                        Add-Member -NotePropertyName trail_atr_mult -NotePropertyValue $trailMult -PassThru
                    $null = $results.Add($result)

                    Write-Host ("[{0}/{1}] {2} => net={3} pf={4} trades={5}" -f `
                        $runIndex, `
                        $totalRuns, `
                        $result.run_name, `
                        $result.total_net_profit, `
                        $result.profit_factor, `
                        $result.total_trades)
                }
            }
        }
    }
}
finally {
    Set-Content -Path $portableSourceResolved -Value $originalText -Encoding UTF8
}

$sorted = $results | Sort-Object total_net_profit -Descending
$outputDir = Split-Path -Path $OutputPath -Parent
if (-not (Test-Path $outputDir)) {
    New-Item -Path $outputDir -ItemType Directory | Out-Null
}

$sorted | ConvertTo-Json -Depth 5 | Set-Content -Path $OutputPath -Encoding UTF8
$sorted | Select-Object -First 15 run_name,total_net_profit,profit_factor,total_trades,balance_drawdown_raw,equity_drawdown_raw,break_even_atr_trigger,break_even_offset_points,trail_start_atr,trail_atr_mult | Format-Table -AutoSize
Write-Host ("Saved=" + $OutputPath)


