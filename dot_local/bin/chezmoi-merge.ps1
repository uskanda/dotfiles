#requires -version 5
# chezmoi-merge.ps1 - Windows entry point for the chezmoi-merge skill.
#
# Windows analog of ~/.local/bin/chezmoi-merge (bash). Both do the same thing:
# cd into the chezmoi source dir, then open an interactive Claude Code session
# seeded with the /chezmoi-merge slash command.
#
# Typing a bare `chezmoi-merge` finds this file because
# %USERPROFILE%\.local\bin is on PATH - see ~/.config/powershell/profile.ps1,
# wired up by setup.ps1's Install-PowerShellProfile. The .ps1 extension cannot
# be dropped on Windows (no shebang, and command lookup is extension-based), but
# it does not have to be typed: PowerShell resolves bare names to .ps1 in a PATH
# directory even though .PS1 is absent from PATHEXT.
#
# Interactive on purpose: the skill asks for a decision per drifted item, so do
# not add -p / --print here.
#
# Comments are English-only. Windows PowerShell 5.1 reads a BOM-less .ps1 as
# CP932 in a Japanese locale, which mangles UTF-8 multibyte text and can eat
# line-continuation backticks. Same rule as setup.ps1.
[CmdletBinding()]
param(
    # Extra text appended to the initial prompt, e.g. `chezmoi-merge tmux only`.
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$Extra
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command chezmoi -ErrorAction SilentlyContinue)) {
    Write-Host "chezmoi-merge: chezmoi not found on PATH." -ForegroundColor Red
    Write-Host "  Install it with: winget install twpayne.chezmoi" -ForegroundColor Yellow
    exit 127
}

if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    Write-Host "chezmoi-merge: the claude CLI was not found on this Windows PATH." -ForegroundColor Red
    # Official package (publisher: Anthropic PBC). It is a 'portable' installer,
    # so winget drops claude.exe under its Links dir, which is already on the
    # user PATH - no wiring from this repo's profile.ps1 needed. Beware the many
    # third-party lookalikes in `winget search claude`: only Anthropic.* is official.
    Write-Host "  Install it with: winget install Anthropic.ClaudeCode --exact" -ForegroundColor Yellow
    # Deliberately not falling back to `wsl.exe claude`: chezmoi inside WSL
    # manages /home/<user>, so that run would reconcile the WSL dotfiles and
    # leave this Windows profile untouched - the opposite of what was asked for.
    Write-Host "  (A claude living in WSL is not reused: it would sync WSL's HOME, not this Windows profile.)" -ForegroundColor DarkGray
    exit 127
}

# The skill works relative to the chezmoi source dir, and running Claude Code
# from there also picks up the repo's CLAUDE.md.
$repo = (& chezmoi source-path | Out-String).Trim()
if (-not $repo -or -not (Test-Path $repo)) {
    Write-Host "chezmoi-merge: could not resolve 'chezmoi source-path' ($repo)." -ForegroundColor Red
    exit 1
}
Set-Location -LiteralPath $repo

$prompt = '/chezmoi-merge'
if ($Extra) { $prompt = "$prompt $($Extra -join ' ')" }

& claude $prompt
if ($null -ne $LASTEXITCODE) { exit $LASTEXITCODE }
