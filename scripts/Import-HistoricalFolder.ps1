param(
    [string]$HistoryFolder = "D:\ps_st\Downloads\Dados Hist*",
    [string]$PortableRoot = (Join-Path $PSScriptRoot "..\mt5-portable"),
    [string[]]$Symbols = @("EURUSD", "GBPUSD", "USDJPY", "AUDUSD", "USDCAD", "XAUUSD", "US500"),
    [string]$Suffix = "_CSV",
    [string]$CustomGroup = "AplexFlow Imports"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$historyMatch = Resolve-Path $HistoryFolder | Select-Object -First 1
if (-not $historyMatch) {
    throw "Nao encontrei a pasta de historicos para '$HistoryFolder'."
}

$historyResolved = $historyMatch.Path
$portableResolved = (Resolve-Path $PortableRoot).Path
$importScript = Join-Path $PSScriptRoot "Import-CustomCsvHistory.ps1"

if (-not (Test-Path $importScript)) {
    throw "Nao encontrei '$importScript'."
}

$files = Get-ChildItem -Path $historyResolved -File -Filter "*.csv"
$results = New-Object System.Collections.Generic.List[object]
$importedSymbols = New-Object System.Collections.Generic.List[string]

foreach ($symbol in $Symbols) {
    $match = $files |
        Where-Object { $_.BaseName -like "$symbol*" } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if (-not $match) {
        $results.Add([pscustomobject]@{
            symbol = $symbol
            imported = $false
            csv = $null
            custom_symbol = $null
            error = "csv_not_found"
        }) | Out-Null
        continue
    }

    $customSymbol = "$symbol$Suffix"
    $json = & $importScript `
        -CsvPath $match.FullName `
        -PortableRoot $portableResolved `
        -CustomSymbol $customSymbol `
        -OriginSymbol $symbol `
        -CustomGroup $CustomGroup

    $parsed = $json | ConvertFrom-Json
    $results.Add([pscustomobject]@{
        symbol = $symbol
        imported = $true
        csv = $match.FullName
        custom_symbol = $customSymbol
        compile_exit_code = $parsed.compile_exit_code
        terminal_exit_code = $parsed.terminal_exit_code
        custom_history_dir = $parsed.custom_history_dir
        latest_log = $parsed.latest_log
    }) | Out-Null
    $importedSymbols.Add($customSymbol) | Out-Null
}

[pscustomobject]@{
    history_folder = $historyResolved
    portable_root = $portableResolved
    suffix = $Suffix
    imported_symbols = $importedSymbols.ToArray()
    imported_symbols_csv = ($importedSymbols -join ",")
    results = $results
} | ConvertTo-Json -Depth 6
