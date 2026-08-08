#requires -version 5
# install-voicevox-engine.ps1 — download & run the VOICEVOX engine on Windows.
#
# Windows analog of the macOS `install-voicevox-engine` (LaunchAgent) script. The
# engine exposes an HTTP API on localhost:50021 that claude-notify.ps1 uses for
# TTS; without it, claude-notify falls back to the built-in SAPI5 voice.
#
# It installs the headless CPU engine (no GUI), runs it hidden in the background,
# and registers a logon Scheduled Task so :50021 is up every session. Idempotent —
# safe to re-run.
#
#   .\install-voicevox-engine.ps1              # install + start + autostart
#   .\install-voicevox-engine.ps1 -Uninstall   # stop + remove task + delete files
#
# Override via env:
#   VOICEVOX_ENGINE_VERSION  default: 0.25.2
#   VOICEVOX_ENGINE_DIR      default: ~\Applications\voicevox_engine
#   VOICEVOX_PORT            default: 50021
[CmdletBinding()]
param(
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'

$Version = if ($env:VOICEVOX_ENGINE_VERSION) { $env:VOICEVOX_ENGINE_VERSION } else { '0.25.2' }
$Port    = if ($env:VOICEVOX_PORT) { $env:VOICEVOX_PORT } else { '50021' }
$InstallDir = if ($env:VOICEVOX_ENGINE_DIR) { $env:VOICEVOX_ENGINE_DIR } else { "$env:USERPROFILE\Applications\voicevox_engine" }
$TaskName = 'VOICEVOX Engine'
$Asset = "voicevox_engine-windows-cpu-$Version.7z.001"
$Url   = "https://github.com/VOICEVOX/voicevox_engine/releases/download/$Version/$Asset"

function Test-EngineUp {
    try {
        Invoke-WebRequest -UseBasicParsing -TimeoutSec 2 -Uri "http://localhost:$Port/version" | Out-Null
        return $true
    } catch { return $false }
}

function Get-RunExe { Join-Path $InstallDir 'run.exe' }

function Start-Engine {
    $run = Get-RunExe
    if (-not (Test-Path $run)) { throw "engine not installed: $run" }
    # Hidden + detached: the engine just serves HTTP; audio plays in the user
    # session via claude-notify.ps1, so it needs no visible console.
    Start-Process -FilePath $run `
        -ArgumentList @('--host', '127.0.0.1', '--port', $Port) `
        -WorkingDirectory $InstallDir -WindowStyle Hidden | Out-Null
}

if ($Uninstall) {
    Write-Host "Removing VOICEVOX engine..."
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    Get-Process run -ErrorAction SilentlyContinue |
        Where-Object { $_.Path -and $_.Path.StartsWith($InstallDir, [StringComparison]::OrdinalIgnoreCase) } |
        Stop-Process -Force -ErrorAction SilentlyContinue
    if (Test-Path $InstallDir) { Remove-Item $InstallDir -Recurse -Force }
    Write-Host "Done."
    return
}

if (Test-EngineUp) {
    Write-Host "VOICEVOX engine already running on :$Port. Nothing to do." -ForegroundColor Green
    return
}

# --- 1. 7-Zip (needed to extract the release archive) ------------------------
$sevenZip = @(
    "$env:ProgramFiles\7-Zip\7z.exe",
    "${env:ProgramFiles(x86)}\7-Zip\7z.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $sevenZip) { $sevenZip = (Get-Command 7z.exe -ErrorAction SilentlyContinue).Source }
if (-not $sevenZip) {
    Write-Host "7-Zip not found — installing via winget..."
    winget install --id 7zip.7zip --exact --silent --accept-source-agreements --accept-package-agreements
    $sevenZip = "$env:ProgramFiles\7-Zip\7z.exe"
    if (-not (Test-Path $sevenZip)) { throw "7-Zip install failed; install it manually and re-run." }
}

# --- 2. Download the headless CPU engine (~1.8GB) ----------------------------
$tmp = Join-Path ([IO.Path]::GetTempPath()) ("voicevox_dl_" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp | Out-Null
try {
    $archive = Join-Path $tmp $Asset
    Write-Host "Downloading $Asset (~1.8GB)... this can take a while."
    # BITS is far faster/robust than Invoke-WebRequest for large files.
    try {
        Start-BitsTransfer -Source $Url -Destination $archive -Description 'VOICEVOX engine'
    } catch {
        Write-Host "  BITS failed, falling back to Invoke-WebRequest..."
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $archive
    }

    # --- 3. Extract ----------------------------------------------------------
    Write-Host "Extracting..."
    $extract = Join-Path $tmp 'extract'
    & $sevenZip x -y "-o$extract" $archive | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "7-Zip extraction failed ($LASTEXITCODE)" }

    $runBin = Get-ChildItem -Path $extract -Filter 'run.exe' -Recurse -File | Select-Object -First 1
    if (-not $runBin) { throw "could not find run.exe after extraction" }
    $srcDir = $runBin.Directory.FullName

    # --- 4. Install ----------------------------------------------------------
    Write-Host "Installing to $InstallDir ..."
    if (Test-Path $InstallDir) { Remove-Item $InstallDir -Recurse -Force }
    New-Item -ItemType Directory -Path $InstallDir | Out-Null
    Copy-Item -Path (Join-Path $srcDir '*') -Destination $InstallDir -Recurse -Force
} finally {
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

# --- 5. Autostart at logon (hidden) ------------------------------------------
Write-Host "Registering logon Scheduled Task '$TaskName'..."
$run = Get-RunExe
$psArgs = "-NoProfile -WindowStyle Hidden -Command " +
    "`"Start-Process -FilePath '$run' -ArgumentList @('--host','127.0.0.1','--port','$Port') " +
    "-WorkingDirectory '$InstallDir' -WindowStyle Hidden`""
$action  = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $psArgs
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger `
    -Settings $settings -Description 'VOICEVOX TTS engine for claude-notify' -Force | Out-Null

# --- 6. Start now & wait -----------------------------------------------------
Write-Host "Starting engine..."
Start-Engine
Write-Host "Waiting for the engine to come up on :$Port (cold start can take a few minutes) ..."
for ($i = 0; $i -lt 150; $i++) {
    if (Test-EngineUp) {
        Write-Host "VOICEVOX engine is up on :$Port." -ForegroundColor Green
        return
    }
    Start-Sleep -Seconds 2
}
Write-Host "Engine did not answer within the timeout, but 'run.exe' may still be loading — re-check http://localhost:$Port/version shortly." -ForegroundColor Yellow
exit 1
