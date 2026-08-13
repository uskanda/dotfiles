#requires -version 5
# PowerShell profile - the chezmoi-managed one.
#
# PowerShell actually loads $PROFILE.CurrentUserAllHosts, which lives under
# Documents. That path is both localized and OneDrive-relocated (on this machine
# it resolves under %USERPROFILE%\OneDrive\<localized Documents>\
# WindowsPowerShell\profile.ps1), and chezmoi maps one source path to one fixed
# target - it cannot compute that at apply time. So chezmoi writes the real
# content here, and setup.ps1's
# Install-PowerShellProfile appends a one-line dot-source shim to the profile
# PowerShell does load. A shim rather than a symlink: no Developer Mode or
# elevation needed, and OneDrive syncs a plain file cleanly.
#
# This is the Windows counterpart of dot_config/zshrc. Keep it to the same
# split: PATH-only bootstrapping belongs here, interactive behaviour (aliases,
# key bindings, prompt) should stay out of an agent's shell just like the
# AGENT_MODE guard keeps it out on the zsh side.
#
# Comments are English-only. Windows PowerShell 5.1 reads a BOM-less .ps1 as
# CP932 in a Japanese locale, which mangles UTF-8 multibyte text. Same rule as
# setup.ps1, and it applies to every .ps1 this repo ships - not just that one.

# --- PATH: %USERPROFILE%\.local\bin -----------------------------------------
# The Windows half of `export PATH="$HOME/.local/bin:$PATH"` in dot_config/zshrc,
# and the reason this repo's own commands are runnable by name on every OS.
# chezmoi drops them all in ~/.local/bin (chezmoi-merge, claude-notify, ...), so
# anything added there later is picked up with no further wiring.
#
# Prepended, matching zsh. The Python launchers that installers leave in this
# directory are version-suffixed (python3.12.exe), so they shadow nothing.
$localBin = Join-Path $env:USERPROFILE '.local\bin'
if ((Test-Path $localBin) -and (($env:PATH -split ';') -notcontains $localBin)) {
    $env:PATH = "$localBin;$env:PATH"
}
Remove-Variable localBin -ErrorAction SilentlyContinue
