# setup.ps1 — Windows post-`chezmoi apply` setup.
#
# Run after `chezmoi apply`. Optional components are opt-in, mirroring the
# INSTALL_VOICEVOX / INSTALL_NOTIFY_DAEMON flags in the Unix `setup` script.
#
#   .\setup.ps1              # base setup only (Alacritty install + config link)
#   .\setup.ps1 -Winget      # base setup + winget packages (win_main_apps.json)
#   .\setup.ps1 -Fusion      # base setup + Autodesk Fusion 360 MCP bridge
#   .\setup.ps1 -Voicevox    # base setup + VOICEVOX engine (claude-notify TTS)
#   $env:INSTALL_FUSION=1; .\setup.ps1   # same, via env var
#
[CmdletBinding()]
param(
    # Opt-in: also install every app listed in win_main_apps.json via winget.
    [switch]$Winget,
    # Opt-in: also install the Autodesk Fusion 360 MCP bridge for Claude Code.
    [switch]$Fusion,
    # Opt-in: also install the VOICEVOX engine so claude-notify speaks with a
    # VOICEVOX voice instead of falling back to the built-in SAPI5 voice.
    [switch]$Voicevox
)

$ErrorActionPreference = 'Stop'

# --- Alacritty: install the terminal itself, and keep it current -------------
# Part of the base setup, not the -Winget bulk import: the config this repo
# manages is useless without the terminal, and it is a small, quick install.
# Alacritty.Alacritty is in win_main_apps.json too, so -Winget also covers it —
# doing it here just keeps a bare `.\setup.ps1` self-contained. That bulk import
# runs --no-upgrade, but this one does upgrade: the terminal this repo actually
# configures is worth keeping on the latest version.
function Install-Alacritty {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host "Alacritty: winget not found — install the terminal manually. Skipping install." -ForegroundColor Yellow
        return
    }

    $wingetArgs = @(
        '--id', 'Alacritty.Alacritty', '--exact', '--silent',
        '--accept-source-agreements', '--accept-package-agreements'
    )

    # `winget list --exact` exits non-zero when nothing matches, so it doubles
    # as the installed check.
    $null = winget list --id Alacritty.Alacritty --exact --accept-source-agreements
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Alacritty: installing via winget ..."
        & winget install @wingetArgs
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Alacritty: winget install exited with $LASTEXITCODE — install it manually. Linking the config anyway." -ForegroundColor Yellow
        } else {
            Write-Host "Alacritty: installed." -ForegroundColor Green
        }
        return
    }

    # setup.ps1 may well have been launched from Alacritty itself. The MSI would
    # close the running terminal mid-setup, so leave the upgrade for next time.
    if (Get-Process alacritty -ErrorAction SilentlyContinue) {
        Write-Host "Alacritty: installed, but running right now — skipping the upgrade so the installer cannot close this terminal. Quit Alacritty and re-run to update." -ForegroundColor Yellow
        return
    }

    # `winget upgrade` is its own check: a no-op exiting 0x8A15002B
    # (UPDATE_NOT_APPLICABLE) when the installed version is already the latest.
    Write-Host "Alacritty: installed — checking for a newer version ..."
    & winget upgrade @wingetArgs
    $UpdateNotApplicable = -1978335189  # 0x8A15002B
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Alacritty: upgraded." -ForegroundColor Green
    } elseif ($LASTEXITCODE -eq $UpdateNotApplicable) {
        Write-Host "Alacritty: already up to date." -ForegroundColor Green
    } else {
        Write-Host "Alacritty: winget upgrade exited with $LASTEXITCODE — check it manually. Linking the config anyway." -ForegroundColor Yellow
    }
}

# --- Alacritty: point %APPDATA%\alacritty at the chezmoi-managed config ------
function Set-AlacrittyLink {
    # chezmoi writes the real config here (dot_config/alacritty/alacritty.toml):
    $src = "$env:USERPROFILE\.config\alacritty\alacritty.toml"
    if (-not (Test-Path $src)) {
        Write-Host "Alacritty: source not found ($src) — run 'chezmoi apply' first. Skipping." -ForegroundColor Yellow
        return
    }
    $dstDir = "$env:APPDATA\alacritty"
    $dst = "$dstDir\alacritty.toml"
    if (-not (Test-Path $dstDir)) { New-Item -ItemType Directory -Path $dstDir | Out-Null }
    if (Test-Path $dst) { Remove-Item $dst -Force }
    # Symlink needs Developer Mode or an elevated shell.
    New-Item -ItemType SymbolicLink -Path $dst -Target $src | Out-Null
    Write-Host "Alacritty: linked $dst -> $src" -ForegroundColor Green
}

# --- winget packages (opt-in) ------------------------------------------------
# The Windows counterpart of dot_Brewfile: installs everything listed in
# win_main_apps.json, which is a `winget export` snapshot. That file is
# .chezmoiignore'd (it never lands in $HOME), so read it from $PSScriptRoot —
# i.e. the dotfiles repo this script was run from.
# Refresh the list with:  winget export -o .\win_main_apps.json
function Install-WingetPackages {
    Write-Host "== winget packages ==" -ForegroundColor Cyan

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host "  winget not found — install 'App Installer' from the Microsoft Store first. Skipping." -ForegroundColor Yellow
        return
    }

    $importFile = Join-Path $PSScriptRoot 'win_main_apps.json'
    if (-not (Test-Path $importFile)) {
        Write-Host "  package list not found ($importFile) — skipping." -ForegroundColor Yellow
        return
    }

    Write-Host "  importing $importFile ..."
    # --no-upgrade keeps re-runs idempotent: install what is missing, leave
    # already-installed versions alone. --ignore-unavailable stops one stale
    # package id from aborting the whole import.
    $wingetArgs = @(
        'import', '--import-file', $importFile,
        '--accept-package-agreements', '--accept-source-agreements',
        '--no-upgrade', '--ignore-unavailable'
    )
    & winget @wingetArgs
    # Skipped/already-installed packages can still yield a non-zero exit code,
    # so warn instead of aborting the rest of setup.
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  winget import exited with $LASTEXITCODE — check the output above for packages that need attention." -ForegroundColor Yellow
    } else {
        Write-Host "  winget import done." -ForegroundColor Green
    }
}

# --- Autodesk Fusion 360 MCP bridge (opt-in) --------------------------------
# Reproduces the ndoo/fusion360-mcp-bridge install: clone -> venv -> add-in ->
# per-machine secret -> register the MCP server in ~/.claude.json.
# The secret and the venv are generated locally; nothing sensitive is committed.
function Install-FusionMcpBridge {
    Write-Host "== Autodesk Fusion 360 MCP bridge ==" -ForegroundColor Cyan

    $repoUrl  = 'https://github.com/ndoo/fusion360-mcp-bridge.git'
    $repoDir  = "$env:USERPROFILE\fusion360-mcp-bridge"
    $venvPy   = "$repoDir\.venv\Scripts\python.exe"
    $server   = "$repoDir\mcp-server\server.py"
    $reqs     = "$repoDir\mcp-server\requirements.txt"
    $addinSrc = "$repoDir\fusion-addin\FusionMCPBridge"
    $addinDir = "$env:APPDATA\Autodesk\Autodesk Fusion 360\API\AddIns"
    $addinDst = "$addinDir\FusionMCPBridge"
    $secret   = "$env:USERPROFILE\.fusion-mcp-secret"

    # 1. Clone the bridge repo (leave an existing checkout untouched).
    if (-not (Test-Path $repoDir)) {
        Write-Host "  cloning $repoUrl ..."
        git clone --depth 1 $repoUrl $repoDir
    } else {
        Write-Host "  repo present: $repoDir (leaving as-is)"
    }

    # 2. Isolated venv with the MCP server's dependencies (mcp, httpx).
    if (-not (Test-Path $venvPy)) {
        Write-Host "  creating venv ..."
        $sysPy = (Get-Command python -ErrorAction Stop).Source
        & $sysPy -m venv "$repoDir\.venv"
    }
    Write-Host "  installing deps (mcp, httpx) ..."
    & $venvPy -m pip install --quiet --upgrade pip
    & $venvPy -m pip install --quiet -r $reqs

    # 3. Shared secret — generated per machine, reused if already present.
    if (Test-Path $secret) {
        Write-Host "  secret exists — keeping it"
    } else {
        $tok = & $venvPy -c 'import secrets; print(secrets.token_hex(32))'
        Set-Content -Path $secret -Value $tok -NoNewline -Encoding ascii
        Write-Host "  generated new secret at $secret"
    }

    # 4. Fusion 360 add-in (requires Fusion to have been launched at least once).
    if (-not (Test-Path $addinDir)) {
        Write-Host "  Fusion add-in dir not found — launch Fusion 360 once, then re-run -Fusion." -ForegroundColor Yellow
    } else {
        if (Test-Path $addinDst) { Remove-Item $addinDst -Recurse -Force }
        Copy-Item $addinSrc $addinDst -Recurse
        Write-Host "  add-in copied to $addinDst"
    }

    # 5. Register the MCP server in ~/.claude.json (user scope, top-level
    #    mcpServers). Current Claude Code rejects mcpServers in settings.json,
    #    so it must live here. Edited via Python json to safely round-trip the
    #    large file (idempotent — rewrites the same entry if already present).
    $cmd = ($venvPy -replace '\\', '/')
    $srv = ($server -replace '\\', '/')
    $pyEdit = @'
import json, os, sys
p = os.path.expanduser("~/.claude.json")
data = {}
if os.path.exists(p):
    with open(p, encoding="utf-8") as f:
        data = json.load(f)
data.setdefault("mcpServers", {})
data["mcpServers"]["fusion360"] = {
    "type": "stdio",
    "command": sys.argv[1],
    "args": [sys.argv[2]],
}
with open(p, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write("\n")
print("  registered fusion360 in ~/.claude.json")
'@
    & $venvPy -c $pyEdit $cmd $srv

    Write-Host ""
    Write-Host "  Manual steps remaining:" -ForegroundColor Cyan
    Write-Host "   1. In Fusion 360: Tools -> Add-Ins (Shift+S) -> select 'FusionMCPBridge' -> Run"
    Write-Host "      (optionally tick 'Run on Startup')."
    Write-Host "   2. Restart Claude Code so it loads the new MCP server."
}

# --- VOICEVOX engine (opt-in) -----------------------------------------------
# Installs/starts the local VOICEVOX engine on :50021 so claude-notify speaks
# with a VOICEVOX voice. Delegates to the dedicated installer (~1.8GB download).
function Install-VoicevoxEngine {
    Write-Host "== VOICEVOX engine ==" -ForegroundColor Cyan
    $installer = "$env:USERPROFILE\.local\bin\install-voicevox-engine.ps1"
    if (-not (Test-Path $installer)) {
        Write-Host "  installer not found ($installer) — run 'chezmoi apply' first. Skipping." -ForegroundColor Yellow
        return
    }
    & $installer
}

# --- run ---------------------------------------------------------------------
Install-Alacritty
Set-AlacrittyLink

if ($Winget -or $env:INSTALL_WINGET -eq '1') {
    Install-WingetPackages
} else {
    Write-Host "Skipping winget packages (use -Winget or INSTALL_WINGET=1 to enable)." -ForegroundColor DarkGray
}

if ($Fusion -or $env:INSTALL_FUSION -eq '1') {
    Install-FusionMcpBridge
} else {
    Write-Host "Skipping Fusion 360 MCP bridge (use -Fusion or INSTALL_FUSION=1 to enable)." -ForegroundColor DarkGray
}

if ($Voicevox -or $env:INSTALL_VOICEVOX -eq '1') {
    Install-VoicevoxEngine
} else {
    Write-Host "Skipping VOICEVOX engine (use -Voicevox or INSTALL_VOICEVOX=1 to enable)." -ForegroundColor DarkGray
}

# Every winget non-zero above is deliberately handled and reported as a warning
# (e.g. "already up to date" is 0x8A15002B), so do not let it leak out as this
# script's exit status. Real failures throw under $ErrorActionPreference='Stop'
# and never reach this line.
exit 0
