param(
    [string]$Godot = $env:GODOT_BIN,
    [ValidateSet('All', 'Desktop', 'Web')][string]$Target = 'All',
    [switch]$SkipImport
)

$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (-not $Godot) {
    $found = Get-Command godot -ErrorAction SilentlyContinue
    if ($found) { $Godot = $found.Source }
}
if (-not $Godot -or -not (Test-Path -LiteralPath $Godot)) {
    throw 'Set GODOT_BIN or pass -Godot with the path to Godot 4.6.1 stable.'
}
$engineVersion = (& $Godot --version | Out-String).Trim()
if (-not $engineVersion.StartsWith('4.6.1.stable')) {
    throw ('This export configuration was validated with Godot 4.6.1 stable; found ' + $engineVersion)
}
$logDirectory = Join-Path $projectRoot 'work/export-logs'
New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
if (-not $SkipImport) {
	$ErrorActionPreference = 'Continue'
    & $Godot --headless --editor --xr-mode off --path $projectRoot --import *> (Join-Path $logDirectory 'import.log')
	$engineExit = $LASTEXITCODE
	$ErrorActionPreference = 'Stop'
    if ($engineExit -ne 0) { throw 'Resource import failed; inspect work/export-logs/import.log.' }
}
$targets = @(
    @{ Group='Desktop'; Preset='Windows Desktop'; File='build/WineVR.exe'; Name='windows' },
    @{ Group='Desktop'; Preset='Linux'; File='build_linux/WineVR.x86_64'; Name='linux' },
    @{ Group='Desktop'; Preset='macOS Desktop'; File='exports/local/macos/WineVR.zip'; Name='macos' },
    @{ Group='Web'; Preset='Web'; File='exports/local/web/WineVR.html'; Name='web' }
)
$results = @()
foreach ($item in $targets) {
    if ($Target -ne 'All' -and $Target -ne $item.Group) { continue }
    $outputPath = Join-Path $projectRoot $item.File
    New-Item -ItemType Directory -Path (Split-Path -Parent $outputPath) -Force | Out-Null
    $logPath = Join-Path $logDirectory ($item.Name + '.log')
	$ErrorActionPreference = 'Continue'
    & $Godot --headless --xr-mode off --path $projectRoot --export-release $item.Preset $outputPath *> $logPath
	$engineExit = $LASTEXITCODE
	$ErrorActionPreference = 'Stop'
    if ($engineExit -ne 0 -or -not (Test-Path -LiteralPath $outputPath)) {
        throw ('Export failed for ' + $item.Preset + '. Inspect ' + $logPath)
    }
    $results += [PSCustomObject]@{
        target = $item.Preset
        path = $item.File
        bytes = (Get-Item -LiteralPath $outputPath).Length
        sha256 = (Get-FileHash -LiteralPath $outputPath -Algorithm SHA256).Hash
        device_tested = $false
    }
    Write-Output ('Exported ' + $item.Preset + ' -> ' + $item.File)
}
$manifest = [PSCustomObject]@{
    generated_utc = [DateTime]::UtcNow.ToString('o')
    engine = $engineVersion
    artifacts = $results
    note = 'Hashes cover primary files. Windows/Linux also require adjacent PCK; Web requires all exported files. Export success does not imply device validation.'
}
$manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $logDirectory 'manifest.json') -Encoding UTF8
