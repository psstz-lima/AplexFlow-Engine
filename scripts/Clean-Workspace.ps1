param(
    [string]$WorkerRoot = (Join-Path $PSScriptRoot "..\mt5-workers"),
    [string]$PortableRoot = (Join-Path $PSScriptRoot "..\mt5-portable"),
    [switch]$IncludePortable,
    [switch]$IncludeScratchLogs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$summary = New-Object System.Collections.Generic.List[object]

function Get-FileStats {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        return @{ Count = 0; Size = 0.0 }
    }

    $files = @(Get-ChildItem -Path $Path -Recurse -Force -File -ErrorAction SilentlyContinue)
    $count = $files.Count
    $size = (($files | Measure-Object -Property Length -Sum).Sum)
    if ($null -eq $size) {
        $size = 0.0
    }

    return @{ Count = $count; Size = [double]$size }
}

function Clear-DirectoryContents {
    param(
        [string]$Path,
        [string]$Label
    )

    if (-not (Test-Path $Path)) {
        return
    }

    $items = @(Get-ChildItem -Path $Path -Force -ErrorAction SilentlyContinue)
    if ($items.Count -eq 0) {
        return
    }

    $stats = Get-FileStats -Path $Path
    foreach ($item in $items) {
        Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction SilentlyContinue
    }

    $summary.Add([pscustomobject]@{
        target = $Label
        removed_files = $stats.Count
        freed_mb = [math]::Round(($stats.Size / 1MB), 2)
    }) | Out-Null
}

function Clear-FilePattern {
    param(
        [string]$Path,
        [string]$Filter,
        [string]$Label
    )

    if (-not (Test-Path $Path)) {
        return
    }

    $items = @(Get-ChildItem -Path $Path -Filter $Filter -Force -ErrorAction SilentlyContinue)
    if ($items.Count -eq 0) {
        return
    }

    $size = (($items | Measure-Object -Property Length -Sum).Sum)
    if ($null -eq $size) {
        $size = 0.0
    }

    foreach ($item in $items) {
        Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction SilentlyContinue
    }

    $summary.Add([pscustomobject]@{
        target = $Label
        removed_files = $items.Count
        freed_mb = [math]::Round(([double]$size / 1MB), 2)
    }) | Out-Null
}

function Clean-Mt5Root {
    param(
        [string]$RootPath,
        [string]$LabelPrefix
    )

    if (-not (Test-Path $RootPath)) {
        return
    }

    foreach ($relativePath in @("logs", "MQL5\Logs", "Tester\logs", "Tester\cache")) {
        Clear-DirectoryContents -Path (Join-Path $RootPath $relativePath) -Label "$LabelPrefix\$relativePath"
    }

    $testerRoot = Join-Path $RootPath "Tester"
    if (Test-Path $testerRoot) {
        $agents = @(Get-ChildItem -Path $testerRoot -Directory -Filter "Agent-*" -ErrorAction SilentlyContinue)
        foreach ($agent in $agents) {
            foreach ($relativePath in @("logs", "temp")) {
                Clear-DirectoryContents -Path (Join-Path $agent.FullName $relativePath) -Label "$LabelPrefix\Tester\$($agent.Name)\$relativePath"
            }
        }
    }

    $basesRoot = Join-Path $RootPath "bases"
    if (Test-Path $basesRoot) {
        $cacheDirs = @(Get-ChildItem -Path $basesRoot -Recurse -Directory -Filter "cache" -ErrorAction SilentlyContinue)
        foreach ($cacheDir in $cacheDirs) {
            $relativeCache = $cacheDir.FullName.Substring($RootPath.Length).TrimStart('\')
            Clear-DirectoryContents -Path $cacheDir.FullName -Label "$LabelPrefix\$relativeCache"
        }
    }
}

$workers = @()
if (Test-Path $WorkerRoot) {
    $workers = @(Get-ChildItem -Path $WorkerRoot -Directory -ErrorAction SilentlyContinue)
}

foreach ($worker in $workers) {
    Clean-Mt5Root -RootPath $worker.FullName -LabelPrefix "mt5-workers\$($worker.Name)"
}

if ($IncludePortable) {
    Clean-Mt5Root -RootPath $PortableRoot -LabelPrefix "mt5-portable"
}

$experimentalRoot = Join-Path $PSScriptRoot "..\reports\archive\experimental"
Clear-FilePattern -Path $experimentalRoot -Filter "_tmp_*" -Label "reports/archive/experimental/_tmp_*"

if ($IncludeScratchLogs) {
    Clear-DirectoryContents -Path (Join-Path $PSScriptRoot "..\scratch\logs") -Label "scratch/logs"
}

$payload = [pscustomobject]@{
    worker_root = $WorkerRoot
    portable_root = $PortableRoot
    include_portable = [bool]$IncludePortable
    include_scratch_logs = [bool]$IncludeScratchLogs
    operations = $summary
    totals = [pscustomobject]@{
        operations = $summary.Count
        removed_files = (($summary | Measure-Object -Property removed_files -Sum).Sum)
        freed_mb = [math]::Round((($summary | Measure-Object -Property freed_mb -Sum).Sum), 2)
    }
}

$payload | ConvertTo-Json -Depth 5
