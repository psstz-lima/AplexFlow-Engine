param(
    [Parameter(Mandatory = $true)]
    [string]$CsvPath,
    [string]$PortableRoot = "",
    [string]$CustomSymbol = "XAUUSD_CSV",
    [string]$OriginSymbol = "XAUUSD",
    [string]$CustomGroup = "Imports",
    [int]$ChunkSize = 50000
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($PortableRoot)) {
    $PortableRoot = Join-Path $PSScriptRoot "..\\mt5-portable"
}

$portableRootResolved = (Resolve-Path $PortableRoot).Path
$csvResolved = (Resolve-Path $CsvPath).Path
$filesDir = Join-Path $portableRootResolved "MQL5\\Files\\imports"
$scriptsDir = Join-Path $portableRootResolved "MQL5\\Scripts"
$presetsDir = Join-Path $portableRootResolved "MQL5\\Presets"
$terminalPath = Join-Path $portableRootResolved "terminal64.exe"
$metaEditorPath = Join-Path $portableRootResolved "MetaEditor64.exe"

if (-not (Test-Path $terminalPath)) {
    throw "Nao encontrei o terminal em '$terminalPath'."
}

if (-not (Test-Path $metaEditorPath)) {
    throw "Nao encontrei o MetaEditor em '$metaEditorPath'."
}

New-Item -ItemType Directory -Force -Path $filesDir | Out-Null
New-Item -ItemType Directory -Force -Path $presetsDir | Out-Null

$csvName = [System.IO.Path]::GetFileName($csvResolved)
$portableCsv = Join-Path $filesDir $csvName
if (([System.IO.Path]::GetFullPath($csvResolved)).ToLowerInvariant() -ne
    ([System.IO.Path]::GetFullPath($portableCsv)).ToLowerInvariant()) {
    Copy-Item -Path $csvResolved -Destination $portableCsv -Force
}

$scriptPath = Join-Path $scriptsDir "ImportCsvToCustomSymbol.mq5"
if (-not (Test-Path $scriptPath)) {
    throw "Nao encontrei o script de importacao em '$scriptPath'."
}

$compileLog = Join-Path $portableRootResolved "compile_import_csv.log"
$scriptResolved = (Resolve-Path $scriptPath).Path
$compileProc = Start-Process -FilePath $metaEditorPath `
    -ArgumentList @("/portable", "/compile:$scriptResolved", "/log:$compileLog") `
    -WorkingDirectory $portableRootResolved `
    -Wait `
    -PassThru

$presetName = "ImportCsvToCustomSymbol.$CustomSymbol.set"
$presetPath = Join-Path $presetsDir $presetName
$presetContent = @"
InpCsvFile=imports\\$csvName
InpCustomSymbol=$CustomSymbol
InpCustomGroup=$CustomGroup
InpOriginSymbol=$OriginSymbol
InpRecreateSymbol=true
InpChunkSize=$ChunkSize
InpSkipHeader=true
"@
[System.IO.File]::WriteAllText($presetPath, $presetContent, [System.Text.Encoding]::ASCII)

$configPath = Join-Path $portableRootResolved "import.$CustomSymbol.ini"
$configContent = @"
[StartUp]
Symbol=$OriginSymbol
Period=M1
Script=ImportCsvToCustomSymbol
ScriptParameters=$presetName
ShutdownTerminal=1
"@
[System.IO.File]::WriteAllText($configPath, $configContent, [System.Text.Encoding]::ASCII)

$beforeLogs = @{}
Get-ChildItem -Path (Join-Path $portableRootResolved "logs") -Filter "*.log" -ErrorAction SilentlyContinue | ForEach-Object {
    $beforeLogs[$_.FullName] = $_.LastWriteTimeUtc
}

$terminalProc = Start-Process -FilePath $terminalPath `
    -ArgumentList @("/portable", "/config:$configPath") `
    -WorkingDirectory $portableRootResolved `
    -Wait `
    -PassThru

$historyDir = Join-Path $portableRootResolved "bases\\Custom\\history\\$CustomSymbol"
$customLog = Get-ChildItem -Path (Join-Path $portableRootResolved "logs") -Filter "*.log" -ErrorAction SilentlyContinue |
    Where-Object {
        -not $beforeLogs.ContainsKey($_.FullName) -or $_.LastWriteTimeUtc -gt $beforeLogs[$_.FullName]
    } |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

[pscustomobject]@{
    csv_source = $csvResolved
    csv_portable = $portableCsv
    custom_symbol = $CustomSymbol
    origin_symbol = $OriginSymbol
    compile_exit_code = $compileProc.ExitCode
    terminal_exit_code = $terminalProc.ExitCode
    compile_log = $compileLog
    startup_config = $configPath
    preset_path = $presetPath
    custom_history_dir = $historyDir
    latest_log = $(if ($customLog) { $customLog.FullName } else { $null })
} | ConvertTo-Json -Depth 4
