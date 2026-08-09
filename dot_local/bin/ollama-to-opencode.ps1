#requires -version 5
# ollama-to-opencode.ps1 - point opencode at local Ollama models.
#
# Windows analog of ~/.local/bin/ollama-to-opencode (bash).
#
# What it does, per model:
#   1. find the largest context that still loads 100% on the GPU (probe, or -Ctx)
#   2. bake that into a `<model>:<tag>` variant via `ollama create` (no disk cost,
#      the blob is reused)
#   3. register it in ~/.config/opencode/opencode.json(c) under an "ollama"
#      provider pointed at http://localhost:11434/v1
#   4. verify with one request through that endpoint
#
# Why the context has to be baked in: opencode talks to Ollama over the
# OpenAI-compatible endpoint, which has no field for num_ctx. Without it Ollama
# falls back to a VRAM-derived default (4096 on a 16 GB card), and opencode's
# system prompt alone is ~9.4k tokens - it gets truncated, so the agent behaves
# badly AND re-prefills every turn because the prompt cache keeps being
# invalidated. Setting OLLAMA_CONTEXT_LENGTH globally is the wrong lever: it
# would also apply to models too big to hold that context in VRAM, pushing them
# onto the CPU.
#
# Usage:
#   ollama-to-opencode                       # show local models and what is registered
#   ollama-to-opencode gpt-oss-20b-mxfp4     # probe, bake, register
#   ollama-to-opencode a b -Default a        # several at once, pick the default
#   ollama-to-opencode a -Ctx 32768          # skip probing
#   ollama-to-opencode a -NoVariant          # register as-is, do not bake a context
#
# Comments are English-only. Windows PowerShell 5.1 reads a BOM-less .ps1 as
# CP932 in a Japanese locale, which mangles UTF-8 multibyte text. Same rule as
# setup.ps1.
[CmdletBinding()]
param(
    # Ollama model refs to register. Omit to list.
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)][string[]]$Model,
    # Context to bake in. Omit to probe for the largest that stays on the GPU.
    [int]$Ctx,
    # Which registered model opencode should default to.
    [string]$Default,
    # Register the model as-is instead of creating a context variant.
    [switch]$NoVariant,
    # Recreate the variant even if it already exists.
    [switch]$Force,
    # Skip the end-to-end request through the OpenAI-compatible endpoint.
    [switch]$NoVerify,
    # List and exit (same as passing no model).
    [switch]$List
)

$ErrorActionPreference = 'Stop'

$PROG = 'ollama-to-opencode'
$OLLAMA_URL = 'http://localhost:11434'
# Smallest context worth handing to a coding agent: opencode's own prompt is
# around 9.4k tokens, so anything under this truncates before the first turn.
$MIN_CTX = 16384

function Fail {
    param([string]$Message, [int]$Code = 1)
    Write-Host "${PROG}: $Message" -ForegroundColor Red
    exit $Code
}

function Warn {
    param([string]$Message)
    Write-Host "${PROG}: $Message" -ForegroundColor Yellow
}

function Info {
    param([string]$Message)
    Write-Host "${PROG}: $Message" -ForegroundColor Cyan
}

# --- ollama ------------------------------------------------------------------
# Deliberately not falling back to `wsl.exe ollama`: that instance has its own
# model store and its own server, and opencode here talks to the Windows one.
$ollama = (Get-Command ollama -ErrorAction SilentlyContinue).Source
if (-not $ollama) {
    $known = Join-Path $env:LOCALAPPDATA 'Programs\Ollama\ollama.exe'
    if (Test-Path $known) { $ollama = $known }
}
if (-not $ollama) {
    Write-Host "${PROG}: ollama not found on PATH." -ForegroundColor Red
    Write-Host "  Install it with: winget install Ollama.Ollama --exact" -ForegroundColor Yellow
    Write-Host "  (Already installed? Open a new shell so PATH picks it up.)" -ForegroundColor DarkGray
    exit 127
}

function Test-OllamaUp {
    try { Invoke-WebRequest -Uri "$OLLAMA_URL/" -TimeoutSec 5 -UseBasicParsing | Out-Null; return $true }
    catch { return $false }
}

# --- opencode config ---------------------------------------------------------
function Get-OpencodeConfigPath {
    $dir = Join-Path $env:USERPROFILE '.config\opencode'
    foreach ($n in @('opencode.jsonc', 'opencode.json')) {
        $p = Join-Path $dir $n
        if (Test-Path $p) { return $p }
    }
    return (Join-Path $dir 'opencode.json')
}

# JSONC in, JSON out. Character-by-character so that "http://localhost" inside a
# string is not mistaken for a line comment - the reason a regex will not do.
# Trailing commas are dropped too, since those are legal in JSONC but not JSON.
function Remove-JsonComment {
    param([string]$Text)
    $sb = New-Object System.Text.StringBuilder
    $inString = $false
    $escape = $false
    $i = 0
    while ($i -lt $Text.Length) {
        $c = $Text[$i]
        if ($inString) {
            [void]$sb.Append($c)
            if ($escape) { $escape = $false }
            elseif ($c -eq '\') { $escape = $true }
            elseif ($c -eq '"') { $inString = $false }
            $i++
            continue
        }
        if ($c -eq '"') { $inString = $true; [void]$sb.Append($c); $i++; continue }
        if ($c -eq '/' -and ($i + 1) -lt $Text.Length) {
            $n = $Text[$i + 1]
            if ($n -eq '/') {
                while ($i -lt $Text.Length -and $Text[$i] -ne "`n") { $i++ }
                continue
            }
            if ($n -eq '*') {
                $i += 2
                while (($i + 1) -lt $Text.Length -and -not ($Text[$i] -eq '*' -and $Text[$i + 1] -eq '/')) { $i++ }
                $i += 2
                continue
            }
        }
        if ($c -eq '}' -or $c -eq ']') {
            $t = $sb.ToString().TrimEnd()
            if ($t.EndsWith(',')) {
                $sb = New-Object System.Text.StringBuilder
                [void]$sb.Append($t.Substring(0, $t.Length - 1))
            }
        }
        [void]$sb.Append($c)
        $i++
    }
    return $sb.ToString()
}

# ConvertFrom-Json hands back PSCustomObject, which cannot take new keys.
# Ordered hashtables can, and ConvertTo-Json keeps their order.
function ConvertTo-OrderedHashtable {
    param($Value)
    if ($null -eq $Value) { return $null }
    if ($Value -is [System.Management.Automation.PSCustomObject]) {
        $h = [ordered]@{}
        foreach ($p in $Value.PSObject.Properties) { $h[$p.Name] = ConvertTo-OrderedHashtable $p.Value }
        return $h
    }
    if ($Value -is [System.Collections.IDictionary]) {
        $h = [ordered]@{}
        foreach ($k in $Value.Keys) { $h[$k] = ConvertTo-OrderedHashtable $Value[$k] }
        return $h
    }
    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
        # Leading comma so an empty array survives: `return @()` would unroll to
        # nothing and turn "disabled_providers": [] into null on the way out.
        return , @($Value | ForEach-Object { ConvertTo-OrderedHashtable $_ })
    }
    return $Value
}

# ConvertTo-Json in Windows PowerShell 5.1 indents by aligning to the key, which
# makes a nested config almost unreadable - and this file is meant to be
# hand-editable. Small serializer instead; the config only holds objects,
# arrays, strings, numbers and booleans.
function ConvertTo-PrettyJson {
    param($Value, [int]$Indent = 0)
    $pad = ' ' * $Indent
    $pad2 = ' ' * ($Indent + 2)
    if ($null -eq $Value) { return 'null' }
    if ($Value -is [bool]) { if ($Value) { return 'true' } else { return 'false' } }
    if ($Value -is [string]) { return (ConvertTo-Json $Value -Compress) }
    if ($Value -is [System.Collections.IDictionary]) {
        if ($Value.Count -eq 0) { return '{}' }
        $items = @(foreach ($k in $Value.Keys) {
                "$pad2$(ConvertTo-Json ([string]$k) -Compress): $(ConvertTo-PrettyJson $Value[$k] ($Indent + 2))"
            })
        return "{`r`n" + ($items -join ",`r`n") + "`r`n$pad}"
    }
    if ($Value -is [System.Collections.IEnumerable]) {
        $arr = @($Value)
        if ($arr.Count -eq 0) { return '[]' }
        $items = @(foreach ($v in $arr) { "$pad2$(ConvertTo-PrettyJson $v ($Indent + 2))" })
        return "[`r`n" + ($items -join ",`r`n") + "`r`n$pad]"
    }
    return (ConvertTo-Json $Value -Compress)
}

function Read-OpencodeConfig {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return [ordered]@{ '$schema' = 'https://opencode.ai/config.json' } }
    $raw = Get-Content -LiteralPath $Path -Raw
    if (-not $raw.Trim()) { return [ordered]@{ '$schema' = 'https://opencode.ai/config.json' } }
    try {
        return ConvertTo-OrderedHashtable ((Remove-JsonComment $raw) | ConvertFrom-Json)
    } catch {
        Fail "could not parse $Path ($($_.Exception.Message)). Fix or move it, then re-run."
    }
}

function Write-OpencodeConfig {
    param([string]$Path, $Config)
    $dir = Split-Path $Path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    if (Test-Path $Path) {
        $bak = "$Path.bak"
        Copy-Item -LiteralPath $Path -Destination $bak -Force
        Info "previous config saved as $bak (comments are not preserved)"
    }
    $json = ConvertTo-PrettyJson $Config
    $header = "// Written by $PROG. Model tags carry a baked-in num_ctx, which is the"
    $header += "`r`n// only way to set the context over the OpenAI-compatible endpoint."
    [System.IO.File]::WriteAllText($Path, "$header`r`n$json`r`n", (New-Object System.Text.UTF8Encoding($false)))
}

# --- context probing ---------------------------------------------------------
# No `2>$null` anywhere near a native command. Windows PowerShell 5.1 turns a
# redirected native stderr line into a NativeCommandError, and with
# $ErrorActionPreference = 'Stop' that becomes a terminating error - which is
# exactly what `ollama stop` on an unloaded model would trip.
function Test-ModelExists {
    param([string]$Ref)
    try { & $ollama show $Ref | Out-Null } catch { return $false }
    return ($LASTEXITCODE -eq 0)
}

function Stop-ModelIfLoaded {
    param([string]$Ref)
    $base = $Ref.Split(':')[0]
    if (((& $ollama ps) -split "`n" | Where-Object { $_ -match [regex]::Escape($base) })) {
        try { & $ollama stop $Ref | Out-Null } catch { }
    }
}

function Get-TrainedCtx {
    param([string]$Ref)
    $show = (& $ollama show $Ref) -join "`n"
    if ($show -match 'context length\s+(\d+)') { return [int]$Matches[1] }
    return 0
}

function Get-LoadedProcessor {
    param([string]$Ref)
    $base = $Ref.Split(':')[0]
    $line = ((& $ollama ps) -split "`n" | Where-Object { $_ -match [regex]::Escape($base) }) -join ' '
    if ($line -match '(\d+%\s*/\s*\d+%\s*CPU/GPU)') { return $Matches[1] }
    if ($line -match '(\d+%\s+GPU)') { return $Matches[1] }
    if ($line -match '(\d+%\s+CPU)') { return $Matches[1] }
    return '?'
}

function Test-CtxFitsGpu {
    param([string]$Ref, [int]$Context)
    Stop-ModelIfLoaded $Ref
    Start-Sleep -Seconds 1
    $body = @{
        model      = $Ref
        messages   = @(@{ role = 'user'; content = 'hi' })
        stream     = $false
        think      = $false
        keep_alive = '30s'
        options    = @{ num_ctx = $Context; num_predict = 1 }
    } | ConvertTo-Json -Depth 6
    try {
        Invoke-RestMethod -Uri "$OLLAMA_URL/api/chat" -Method Post -Body $body -ContentType 'application/json' -TimeoutSec 900 | Out-Null
    } catch {
        return @{ Ok = $false; Processor = 'load failed' }
    }
    $proc = Get-LoadedProcessor $Ref
    Stop-ModelIfLoaded $Ref
    return @{ Ok = ($proc -match '^100%\s+GPU$'); Processor = $proc }
}

function Find-MaxGpuCtx {
    param([string]$Ref)
    $start = Get-TrainedCtx $Ref
    if ($start -le 0) { $start = 131072 }
    $candidates = @()
    $c = $start
    while ($c -ge $MIN_CTX) {
        $candidates += $c
        $c = [int][math]::Floor($c / 2)
    }
    foreach ($c in $candidates) {
        Write-Host ("  probing {0,7} ... " -f $c) -NoNewline
        $r = Test-CtxFitsGpu -Ref $Ref -Context $c
        Write-Host $r.Processor
        if ($r.Ok) { return $c }
    }
    Warn "$Ref never fits entirely in VRAM. Using $MIN_CTX; expect CPU offload and slow generation."
    return $MIN_CTX
}

function Format-CtxTag {
    param([int]$Context)
    if ($Context -ge 1024 -and ($Context % 1024) -eq 0) { return "$([int]($Context / 1024))k" }
    return "$Context"
}

# --- main --------------------------------------------------------------------
if (-not (Test-OllamaUp)) {
    Fail "the Ollama server is not answering on $OLLAMA_URL. Start the Ollama app (or run: ollama serve)."
}

$configPath = Get-OpencodeConfigPath

if ($List -or -not $Model) {
    Write-Host 'Local Ollama models:' -ForegroundColor Cyan
    & $ollama list
    Write-Host ''
    Write-Host "opencode config: $configPath" -ForegroundColor Cyan
    if (Test-Path $configPath) {
        $cfg = Read-OpencodeConfig $configPath
        $registered = @()
        if ($cfg.provider -and $cfg.provider.ollama -and $cfg.provider.ollama.models) {
            $registered = @($cfg.provider.ollama.models.Keys)
        }
        if ($registered.Count) {
            Write-Host "  registered: $($registered -join ', ')"
        } else {
            Write-Host '  registered: (none)'
        }
        if ($cfg.model) { Write-Host "  default   : $($cfg.model)" }
    } else {
        Write-Host '  (does not exist yet)'
    }
    Write-Host ''
    Write-Host "Register one with: $PROG <model>" -ForegroundColor DarkGray
    exit 0
}

$registeredRefs = @()
foreach ($m in $Model) {
    if (-not (Test-ModelExists $m)) { Fail "ollama has no model '$m'. Run '$PROG' with no arguments to list." }

    if ($NoVariant) {
        Info "registering $m as-is (-NoVariant)"
        $registeredRefs += $m
        continue
    }

    if ($Ctx -gt 0) {
        $target = $Ctx
        Info "$m : using -Ctx $target"
    } else {
        Info "$m : probing for the largest context that stays 100% on the GPU"
        $target = Find-MaxGpuCtx $m
    }

    # Keep whatever tag the source already had, so `ornith:9b` becomes
    # `ornith:9b-256k` and not `ornith:256k` - dropping the size would make two
    # different models of the same family collide on one name.
    $base = $m.Split(':')[0]
    $srcTag = if ($m.Contains(':')) { $m.Substring($m.IndexOf(':') + 1) } else { 'latest' }
    $ctxTag = Format-CtxTag $target
    if ($srcTag -eq 'latest' -or $srcTag -eq $ctxTag -or $srcTag.EndsWith("-$ctxTag")) {
        # Nothing to preserve, or the tag already carries this context.
        $newTag = if ($srcTag -eq 'latest') { $ctxTag } else { $srcTag }
    } else {
        $newTag = "$srcTag-$ctxTag"
    }
    $ref = "${base}:$newTag"

    $manifest = Join-Path $env:USERPROFILE ".ollama\models\manifests\registry.ollama.ai\library\$($ref -replace ':', '\')"
    if ($env:OLLAMA_MODELS) {
        $manifest = Join-Path $env:OLLAMA_MODELS "manifests\registry.ollama.ai\library\$($ref -replace ':', '\')"
    }
    if ((Test-Path $manifest) -and -not $Force) {
        Info "$ref already exists, keeping it (-Force to recreate)"
    } else {
        $modelfile = Join-Path ([System.IO.Path]::GetTempPath()) 'Modelfile.ollama-to-opencode'
        $text = "FROM $m`r`nPARAMETER num_ctx $target`r`n"
        [System.IO.File]::WriteAllText($modelfile, $text, (New-Object System.Text.UTF8Encoding($false)))
        & $ollama create $ref -f $modelfile
        $code = $LASTEXITCODE
        Remove-Item $modelfile -Force -ErrorAction SilentlyContinue
        if ($code -ne 0) { Fail "ollama create $ref failed (exit $code)." $code }
        Info "created $ref (num_ctx $target, no extra disk - the blob is shared)"
    }
    $registeredRefs += $ref
}

# --- merge into the opencode config -----------------------------------------
$cfg = Read-OpencodeConfig $configPath
if (-not $cfg.Contains('$schema')) { $cfg['$schema'] = 'https://opencode.ai/config.json' }
if (-not $cfg.Contains('provider') -or $null -eq $cfg['provider']) { $cfg['provider'] = [ordered]@{} }
if (-not $cfg['provider'].Contains('ollama') -or $null -eq $cfg['provider']['ollama']) {
    $cfg['provider']['ollama'] = [ordered]@{}
}
$prov = $cfg['provider']['ollama']
$prov['name'] = 'Ollama'
# opencode has no built-in Ollama provider; the OpenAI-compatible adapter plus
# Ollama's /v1 endpoint is the supported path.
$prov['npm'] = '@ai-sdk/openai-compatible'
if (-not $prov.Contains('options') -or $null -eq $prov['options']) { $prov['options'] = [ordered]@{} }
$prov['options']['baseURL'] = "$OLLAMA_URL/v1"
if (-not $prov.Contains('models') -or $null -eq $prov['models']) { $prov['models'] = [ordered]@{} }
foreach ($ref in $registeredRefs) {
    if (-not $prov['models'].Contains($ref)) {
        $prov['models'][$ref] = [ordered]@{ name = $ref }
    }
}

if ($Default) {
    if ($Default -notlike 'ollama/*') { $Default = "ollama/$Default" }
    $cfg['model'] = $Default
} elseif (-not $cfg.Contains('model') -or -not $cfg['model']) {
    $cfg['model'] = "ollama/$($registeredRefs[0])"
}

Write-OpencodeConfig -Path $configPath -Config $cfg
Info "wrote $configPath"
Write-Host "  registered: $($registeredRefs -join ', ')"
Write-Host "  default   : $($cfg['model'])"

# --- verify ------------------------------------------------------------------
if ($NoVerify) { exit 0 }

$verifyRef = ($cfg['model'] -replace '^ollama/', '')
Info "verifying $verifyRef through $OLLAMA_URL/v1 ..."
$body = @{ model = $verifyRef; messages = @(@{ role = 'user'; content = 'hi' }); max_tokens = 1 } | ConvertTo-Json -Depth 6
try {
    Invoke-RestMethod -Uri "$OLLAMA_URL/v1/chat/completions" -Method Post -Body $body -ContentType 'application/json' -TimeoutSec 900 | Out-Null
} catch {
    Warn "the OpenAI-compatible endpoint returned an error: $($_.Exception.Message)"
    exit 1
}
$proc = Get-LoadedProcessor $verifyRef
$line = ((& $ollama ps) -split "`n" | Where-Object { $_ -match [regex]::Escape($verifyRef.Split(':')[0]) }) -join ' '
$loadedCtx = '?'
if ($line -match '(?:GPU|CPU)\s+(\d+)\s') { $loadedCtx = $Matches[1] }
Write-Host "ok: $verifyRef answered over /v1, context $loadedCtx, $proc" -ForegroundColor Green
Write-Host "  try it with: opencode run `"hello`"" -ForegroundColor DarkGray
