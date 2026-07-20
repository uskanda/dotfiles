# setup.ps1 — Windows post-`chezmoi apply` setup.
#
# Run after `chezmoi apply`. Optional components are opt-in, mirroring the
# INSTALL_VOICEVOX / INSTALL_NOTIFY_DAEMON flags in the Unix `setup` script.
#
#   .\setup.ps1              # base setup only (Alacritty link)
#   .\setup.ps1 -Fusion      # base setup + Autodesk Fusion 360 MCP bridge
#   $env:INSTALL_FUSION=1; .\setup.ps1   # same, via env var
#
[CmdletBinding()]
param(
    # Opt-in: also install the Autodesk Fusion 360 MCP bridge for Claude Code.
    [switch]$Fusion
)

$ErrorActionPreference = 'Stop'

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

# --- run ---------------------------------------------------------------------
Set-AlacrittyLink

if ($Fusion -or $env:INSTALL_FUSION -eq '1') {
    Install-FusionMcpBridge
} else {
    Write-Host "Skipping Fusion 360 MCP bridge (use -Fusion or INSTALL_FUSION=1 to enable)." -ForegroundColor DarkGray
}
