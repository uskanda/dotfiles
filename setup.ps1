# setup.ps1 — Windows post-`chezmoi apply` setup.
#
# Run after `chezmoi apply`. Optional components are opt-in, mirroring the
# INSTALL_VOICEVOX / INSTALL_NOTIFY_DAEMON flags in the Unix `setup` script.
#
#   .\setup.ps1              # base setup only (terminal install + config link)
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

# --- Terminals: install them, and keep them current --------------------------
# Part of the base setup, not the -Winget bulk import: the configs this repo
# manages are useless without the terminal, and these are small, quick installs.
# Both ids are in win_main_apps.json too, so -Winget also covers them — doing it
# here just keeps a bare `.\setup.ps1` self-contained. That bulk import runs
# --no-upgrade, but this one does upgrade: the terminals this repo actually
# configures are worth keeping on the latest version.
function Install-Terminal {
    param(
        # winget package id, e.g. 'wez.wezterm'.
        [Parameter(Mandatory)][string]$Id,
        # Human-readable name used in the log lines.
        [Parameter(Mandatory)][string]$Name,
        # Process names to check before upgrading. setup.ps1 may well have been
        # launched from the terminal being upgraded, and the MSI would close it
        # mid-setup, so the upgrade is skipped while it is running.
        [string[]]$ProcessName = @()
    )

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host "${Name}: winget not found — install the terminal manually. Skipping install." -ForegroundColor Yellow
        return
    }

    $wingetArgs = @(
        '--id', $Id, '--exact', '--silent',
        '--accept-source-agreements', '--accept-package-agreements'
    )

    # `winget list --exact` exits non-zero when nothing matches, so it doubles
    # as the installed check.
    $null = winget list --id $Id --exact --accept-source-agreements
    if ($LASTEXITCODE -ne 0) {
        Write-Host "${Name}: installing via winget ..."
        & winget install @wingetArgs
        if ($LASTEXITCODE -ne 0) {
            Write-Host "${Name}: winget install exited with $LASTEXITCODE — install it manually. Continuing with the config anyway." -ForegroundColor Yellow
        } else {
            Write-Host "${Name}: installed." -ForegroundColor Green
        }
        return
    }

    foreach ($p in $ProcessName) {
        if (Get-Process $p -ErrorAction SilentlyContinue) {
            Write-Host "${Name}: installed, but running right now — skipping the upgrade so the installer cannot close this terminal. Quit it and re-run to update." -ForegroundColor Yellow
            return
        }
    }

    # `winget upgrade` is its own check: a no-op exiting 0x8A15002B
    # (UPDATE_NOT_APPLICABLE) when the installed version is already the latest.
    Write-Host "${Name}: installed — checking for a newer version ..."
    & winget upgrade @wingetArgs
    $UpdateNotApplicable = -1978335189  # 0x8A15002B
    if ($LASTEXITCODE -eq 0) {
        Write-Host "${Name}: upgraded." -ForegroundColor Green
    } elseif ($LASTEXITCODE -eq $UpdateNotApplicable) {
        Write-Host "${Name}: already up to date." -ForegroundColor Green
    } else {
        Write-Host "${Name}: winget upgrade exited with $LASTEXITCODE — check it manually. Continuing with the config anyway." -ForegroundColor Yellow
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

# --- WezTerm: nothing to link, just check the config landed ------------------
# Unlike Alacritty, WezTerm reads %USERPROFILE%\.wezterm.lua directly, and that
# is exactly where chezmoi writes dot_wezterm.lua. So there is no symlink step —
# only a check that `chezmoi apply` has been run, because without that config
# there is no WSL default domain and the ssh-window wrapper
# (~/.config/shell/ssh-window.sh) has nothing to spawn into.
function Test-WezTermConfig {
    $cfg = "$env:USERPROFILE\.wezterm.lua"
    if (Test-Path $cfg) {
        Write-Host "WezTerm: config in place ($cfg)" -ForegroundColor Green
    } else {
        Write-Host "WezTerm: config not found ($cfg) — run 'chezmoi apply' first." -ForegroundColor Yellow
    }
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
Install-Terminal -Id 'Alacritty.Alacritty' -Name 'Alacritty' -ProcessName 'alacritty'
Set-AlacrittyLink

# wezterm-gui.exe is the process that actually holds a window open; wezterm.exe
# is the CLI front-end. Check both so an open terminal is never killed by the MSI.
Install-Terminal -Id 'wez.wezterm' -Name 'WezTerm' -ProcessName 'wezterm-gui', 'wezterm'
Test-WezTermConfig

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
