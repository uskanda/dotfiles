#requires -version 5
# lmstudio-to-opencode.ps1 - LM Studio model to a working opencode setup, in one go.
#
# Windows analog of ~/.local/bin/lmstudio-to-opencode (bash).
#
# It is only an orchestrator; the work lives in the two commands next to it, and
# either can still be run on its own:
#
#   lmstudio-to-ollama   import the .gguf, then hard-link the blob back to
#                        LM Studio's copy so the bytes are not stored twice
#   ollama-to-opencode   find the largest context that stays on the GPU, bake it
#                        into a `<model>:<tag>` variant, register it in
#                        opencode's config, and verify the endpoint answers
#
# Usage:
#   lmstudio-to-opencode                    # list what LM Studio has
#   lmstudio-to-opencode qwen3.6-27b        # import + configure + verify
#   lmstudio-to-opencode a b -Default a     # several, and pick opencode's default
#   lmstudio-to-opencode -All               # every LM Studio model
#   lmstudio-to-opencode a -Ctx 32768       # skip context probing
#
# Comments are English-only. Windows PowerShell 5.1 reads a BOM-less .ps1 as
# CP932 in a Japanese locale, which mangles UTF-8 multibyte text. Same rule as
# setup.ps1.
[CmdletBinding()]
param(
    # Substring of the .gguf path, or the path itself. Omit to list.
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)][string[]]$Model,
    # Context to bake in. Omit to probe for the largest that stays on the GPU.
    [int]$Ctx,
    # Which model opencode should default to (an LM Studio substring is fine).
    [string]$Default,
    # Import every model LM Studio has.
    [switch]$All,
    # Re-import / recreate even if it is already there.
    [switch]$Force,
    # Skip the end-to-end request at the end.
    [switch]$NoVerify,
    # List and exit (same as passing no model).
    [switch]$List
)

$ErrorActionPreference = 'Stop'

$PROG = 'lmstudio-to-opencode'
$importer = Join-Path $PSScriptRoot 'lmstudio-to-ollama.ps1'
$configurer = Join-Path $PSScriptRoot 'ollama-to-opencode.ps1'

function Fail {
    param([string]$Message, [int]$Code = 1)
    Write-Host "${PROG}: $Message" -ForegroundColor Red
    exit $Code
}

foreach ($p in @($importer, $configurer)) {
    if (-not (Test-Path $p)) { Fail "missing $p - run 'chezmoi apply' to install the whole set." 127 }
}

if ($List -or (-not $Model -and -not $All)) {
    & $importer -List
    Write-Host ''
    Write-Host "Run the whole pipeline with: $PROG <substring of the path>" -ForegroundColor DarkGray
    exit 0
}

$targets = @()
if ($All) {
    $targets = @(& $importer -ListPaths)
    if (-not $targets.Count) { Fail 'LM Studio has no importable .gguf.' }
    Write-Host "${PROG}: importing all $($targets.Count) LM Studio models" -ForegroundColor Cyan
} else {
    $targets = $Model
}

# --- step 1: LM Studio -> Ollama ---------------------------------------------
$refs = @()
foreach ($t in $targets) {
    Write-Host "${PROG}: [1/2] importing $t" -ForegroundColor Cyan
    # Hashtable splatting, not an array: array splatting binds positionally, so
    # a "-PrintRef" element would be handed over as a second positional value.
    $importArgs = @{ Model = $t; PrintRef = $true }
    if ($Force) { $importArgs['Force'] = $true }
    $ref = & $importer @importArgs
    if ($LASTEXITCODE -ne 0 -or -not $ref) { Fail "import of '$t' failed." }
    # -PrintRef puts the ref, and nothing else, on stdout.
    $refs += ($ref | Select-Object -Last 1).ToString().Trim()
}

# --- step 2: Ollama -> opencode ----------------------------------------------
Write-Host "${PROG}: [2/2] configuring opencode for $($refs -join ', ')" -ForegroundColor Cyan
$configArgs = @{ Model = $refs }
if ($Ctx -gt 0) { $configArgs['Ctx'] = $Ctx }
if ($Force) { $configArgs['Force'] = $true }
if ($NoVerify) { $configArgs['NoVerify'] = $true }
if ($Default) {
    # The user may have named the default the LM Studio way; map it onto the ref
    # that import actually produced.
    $hit = $refs | Where-Object { $_ -like "*$($Default -replace '[^a-zA-Z0-9._-]', '-')*" } | Select-Object -First 1
    if (-not $hit) { $hit = $Default }
    $configArgs['Default'] = $hit
}
& $configurer @configArgs
if ($LASTEXITCODE -ne 0) { Fail "opencode configuration failed (exit $LASTEXITCODE)." $LASTEXITCODE }
