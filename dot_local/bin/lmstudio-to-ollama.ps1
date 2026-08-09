#requires -version 5
# lmstudio-to-ollama.ps1 - hand a model LM Studio already downloaded to Ollama.
#
# Windows analog of ~/.local/bin/lmstudio-to-ollama (bash); both do the same
# two steps.
#
# Why two steps: Ollama does not read a directory of .gguf files. Its store is
# content-addressed (manifests + blobs named sha256-<digest>), so LM Studio's
# ~/.lmstudio/models/<publisher>/<repo>/<file>.gguf cannot simply be pointed at
# with OLLAMA_MODELS. The only import path is `ollama create` with a Modelfile
# whose FROM is the .gguf - and that COPIES the file into the blob store, so a
# 20 GB model costs 20 GB twice.
#
# So: import (copy), then replace the fresh blob with a hard link back to the
# LM Studio file. Same volume, same bytes, one copy on disk. Deleting either
# name later leaves the other working, because a hard link is just a second
# name for the same data - `ollama rm` does not take LM Studio's model with it.
#
# Measured on Bonsai-27B-Q1_0 (3.54 GB): create 29.8s and +3.55 GB, then the
# link swap gave the 3.55 GB back and inference still ran after `ollama stop`
# forced a reload from disk. GGUF metadata (chat template, capabilities) is
# read by `ollama create`, so /api/chat works without writing a TEMPLATE.
#
# Not handled: mmproj-*.gguf vision projectors. There is no Modelfile directive
# to attach one, so an imported vision model is text-only. They are skipped.
#
# Usage:
#   lmstudio-to-ollama                 # list what LM Studio has, with the name each would get
#   lmstudio-to-ollama qwen3.6-27b     # substring match against those paths
#   lmstudio-to-ollama <path.gguf>     # or an explicit file
#   lmstudio-to-ollama gpt-oss -Name gpt-oss:20b
#   lmstudio-to-ollama gpt-oss -Copy   # keep the plain copy, skip the hard link
#
# Comments are English-only. Windows PowerShell 5.1 reads a BOM-less .ps1 as
# CP932 in a Japanese locale, which mangles UTF-8 multibyte text and can eat
# line-continuation backticks. Same rule as setup.ps1.
[CmdletBinding()]
param(
    # Substring of the .gguf path, or the path itself. Omit to list.
    [Parameter(Position = 0)][string]$Model,
    # Ollama model name, optionally name:tag. Defaults to the file name.
    [string]$Name,
    # Keep the copy ollama create makes instead of hard-linking it away.
    [switch]$Copy,
    # Re-import even if Ollama already has that name:tag.
    [switch]$Force,
    # List and exit (same as passing no model).
    [switch]$List
)

$ErrorActionPreference = 'Stop'

function Fail {
    param([string]$Message, [int]$Code = 1)
    Write-Host "lmstudio-to-ollama: $Message" -ForegroundColor Red
    exit $Code
}

function Warn {
    param([string]$Message)
    Write-Host "lmstudio-to-ollama: $Message" -ForegroundColor Yellow
}

# --- where each side keeps its models ----------------------------------------
# LM Studio records its (movable) download folder in settings.json.
$lmDir = $env:LMSTUDIO_MODELS_DIR
if (-not $lmDir) {
    $settings = Join-Path $env:USERPROFILE '.lmstudio\settings.json'
    if (Test-Path $settings) {
        try { $lmDir = (Get-Content $settings -Raw | ConvertFrom-Json).downloadsFolder } catch { }
    }
}
if (-not $lmDir) { $lmDir = Join-Path $env:USERPROFILE '.lmstudio\models' }
if (-not (Test-Path $lmDir)) { Fail "LM Studio models directory not found ($lmDir)." }

$ollamaDir = $env:OLLAMA_MODELS
if (-not $ollamaDir) { $ollamaDir = Join-Path $env:USERPROFILE '.ollama\models' }

# --- discover ----------------------------------------------------------------
# Skip vision projectors, and for a sharded model keep only the first shard
# (ollama reads the rest by itself from the same directory).
$ggufs = @(Get-ChildItem -LiteralPath $lmDir -Recurse -File -Filter *.gguf |
    Where-Object { $_.Name -notlike 'mmproj-*' } |
    Where-Object { $_.Name -notmatch '-\d{5}-of-\d{5}\.gguf$' -or $_.Name -match '-00001-of-\d{5}\.gguf$' } |
    Sort-Object FullName)

if ($ggufs.Count -eq 0) { Fail "no .gguf files under $lmDir." }

function Get-DefaultName {
    param([System.IO.FileInfo]$File)
    $n = [System.IO.Path]::GetFileNameWithoutExtension($File.Name).ToLowerInvariant()
    $n = $n -replace '-\d{5}-of-\d{5}$', ''
    $n = $n -replace '[^a-z0-9._-]', '-'
    return $n
}

if ($List -or -not $Model) {
    Write-Host "LM Studio models under $lmDir" -ForegroundColor Cyan
    $ggufs | ForEach-Object {
        [PSCustomObject]@{
            GB           = [math]::Round($_.Length / 1GB, 2)
            'ollama name' = Get-DefaultName $_
            Path         = $_.FullName.Substring($lmDir.Length).TrimStart('\')
        }
    } | Format-Table -AutoSize
    Write-Host "Import one with: lmstudio-to-ollama <substring of the path>" -ForegroundColor DarkGray
    exit 0
}

# --- ollama ------------------------------------------------------------------
# Only needed from here on: listing works without it.
# The installer puts ollama.exe on PATH, but a shell opened before the install
# will not see it yet, so fall back to the known install location.
# Deliberately not falling back to `wsl.exe ollama`: that instance has its own
# model store under /home/<user> and cannot hard-link to a file on the Windows
# volume anyway.
$ollama = (Get-Command ollama -ErrorAction SilentlyContinue).Source
if (-not $ollama) {
    $known = Join-Path $env:LOCALAPPDATA 'Programs\Ollama\ollama.exe'
    if (Test-Path $known) { $ollama = $known }
}
if (-not $ollama) {
    Write-Host "lmstudio-to-ollama: ollama not found on PATH." -ForegroundColor Red
    Write-Host "  Install it with: winget install Ollama.Ollama --exact" -ForegroundColor Yellow
    Write-Host "  (Already installed? Open a new shell so PATH picks it up.)" -ForegroundColor DarkGray
    exit 127
}

# --- pick the file -----------------------------------------------------------
if (Test-Path -LiteralPath $Model -PathType Leaf) {
    $src = Get-Item -LiteralPath $Model
} else {
    $hits = @($ggufs | Where-Object { $_.FullName -like "*$Model*" })
    if ($hits.Count -eq 0) { Fail "nothing matches '$Model'. Run with no arguments to list." }
    if ($hits.Count -gt 1) {
        Write-Host "lmstudio-to-ollama: '$Model' matches more than one model:" -ForegroundColor Red
        $hits | ForEach-Object { Write-Host "  $($_.FullName)" }
        exit 1
    }
    $src = $hits[0]
}

if (-not $Name) { $Name = Get-DefaultName $src }
$tag = 'latest'
if ($Name -match '^(.+):([^:]+)$') { $tag = $Matches[2]; $Name = $Matches[1] }
$ref = "${Name}:${tag}"

$manifest = Join-Path $ollamaDir "manifests\registry.ollama.ai\library\$Name\$tag"
if ((Test-Path $manifest) -and -not $Force) {
    Fail "ollama already has '$ref'. Pass -Force to re-import, or -Name to use another name."
}

# ollama create copies before anything can be reclaimed, so the copy has to fit.
try {
    $free = (Get-PSDrive ([System.IO.Path]::GetPathRoot($ollamaDir)[0]) -ErrorAction Stop).Free
    if ($free -lt $src.Length) {
        Fail ("need {0:N1} GB free for the temporary copy, only {1:N1} GB left." -f ($src.Length / 1GB), ($free / 1GB))
    }
} catch [System.Management.Automation.DriveNotFoundException] { }

# --- import ------------------------------------------------------------------
Write-Host "importing $($src.Name) ($([math]::Round($src.Length / 1GB, 2)) GB) as $ref" -ForegroundColor Cyan
$modelfile = Join-Path ([System.IO.Path]::GetTempPath()) 'Modelfile.lmstudio-to-ollama'
# No BOM: the Modelfile is parsed as plain text and a BOM lands in the FROM path.
[System.IO.File]::WriteAllText($modelfile, "FROM $($src.FullName)`r`n", (New-Object System.Text.UTF8Encoding($false)))
& $ollama create $ref -f $modelfile
$createExit = $LASTEXITCODE
Remove-Item $modelfile -Force -ErrorAction SilentlyContinue
if ($createExit -ne 0) { Fail "ollama create failed (exit $createExit)." $createExit }

if ($Copy) {
    Write-Host "done: $ref (kept as a copy, -Copy)" -ForegroundColor Green
    exit 0
}

# --- swap the blob for a hard link -------------------------------------------
# Everything below is best-effort: on any doubt keep the copy, which works.
if ([System.IO.Path]::GetPathRoot($src.FullName) -ne [System.IO.Path]::GetPathRoot($ollamaDir)) {
    Warn "LM Studio and Ollama are on different volumes - hard link not possible, keeping the copy."
    exit 0
}

# Unload first: the link swap deletes and recreates the blob under the server.
# No stderr redirect here. Windows PowerShell 5.1 turns a redirected native
# stderr line into a NativeCommandError, which $ErrorActionPreference = 'Stop'
# then promotes to a terminating error - and `ollama stop` does write to stderr
# when the model is not currently loaded, which is the normal case here.
try { & $ollama stop $ref | Out-Null } catch { }

if (-not (Test-Path $manifest)) { Warn "manifest not found ($manifest), keeping the copy."; exit 0 }
$layer = (Get-Content $manifest -Raw | ConvertFrom-Json).layers |
    Where-Object { $_.mediaType -eq 'application/vnd.ollama.image.model' } | Select-Object -First 1
if (-not $layer) { Warn "no model layer in the manifest, keeping the copy."; exit 0 }

$blob = Join-Path $ollamaDir ('blobs\' + ($layer.digest -replace ':', '-'))
if (-not (Test-Path $blob)) { Warn "blob not found ($blob), keeping the copy."; exit 0 }
if ((Get-Item $blob).Length -ne $src.Length) {
    # ollama requantized or rewrote the file, so the two are not the same bytes.
    Warn "blob size differs from the source, keeping the copy."
    exit 0
}

$tmpLink = "$blob.hardlink.tmp"
if (Test-Path $tmpLink) { Remove-Item $tmpLink -Force }
try {
    New-Item -ItemType HardLink -Path $tmpLink -Target $src.FullName -ErrorAction Stop | Out-Null
} catch {
    Warn "could not hard-link ($($_.Exception.Message)), keeping the copy."
    exit 0
}
# Link first, delete second: if this machine dies in between, re-running fixes it.
Remove-Item $blob -Force
Move-Item -LiteralPath $tmpLink -Destination $blob

Write-Host ("done: $ref - hard-linked, {0:N1} GB of duplicate data reclaimed" -f ($src.Length / 1GB)) -ForegroundColor Green
Write-Host "  run it with: ollama run $ref" -ForegroundColor DarkGray
