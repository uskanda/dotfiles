#requires -version 5
# claude-notify.ps1 — Windows-side speaker for claude-notify.
#
# This is the Windows analog of the macOS `say`/VOICEVOX+afplay path. It is the
# single "make sound on Windows" implementation shared by all three entry points:
#   - env1  native Windows + Git Bash : claude-notify (bash) -> powershell.exe -File ...
#   - env2  WSL2                       : claude-notify (bash) -> powershell.exe (interop)
#   - env3  Windows <- SSH <- Linux    : claude-notify-daemon (python) -> powershell.exe
#
# Two-tier, mirroring the Mac: VOICEVOX (localhost:50021) -> WAV via SoundPlayer,
# falling back to the built-in SAPI5 voice (System.Speech) when VOICEVOX is absent
# or unreachable.
#
# The message is passed base64(UTF-8) via -B64 so Japanese text survives the
# WSL/Git Bash -> Windows process boundary and the console code page unscathed.
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$B64,
  [int]$Speaker = 8,
  [string]$VoicevoxUrl = $env:VOICEVOX_URL,
  [int]$TimeoutSec = 20
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($VoicevoxUrl)) { $VoicevoxUrl = 'http://localhost:50021' }
$VoicevoxUrl = $VoicevoxUrl.TrimEnd('/')

# Decode the UTF-8 message; bail quietly on garbage or emptiness.
try {
  $msg = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($B64))
} catch {
  exit 0
}
if ([string]::IsNullOrWhiteSpace($msg)) { exit 0 }

function Speak-Voicevox {
  param([string]$Text, [int]$Speaker, [string]$BaseUrl, [int]$TimeoutSec)

  # audio_query: text+speaker go in the query string (no body), exactly like the
  # bash/curl path. Keep the raw JSON string and hand it straight to synthesis so
  # we don't risk altering it by round-tripping through PowerShell objects.
  $enc = [uri]::EscapeDataString($Text)
  $queryResp = Invoke-WebRequest -Method Post -UseBasicParsing -TimeoutSec $TimeoutSec `
    -Uri ("{0}/audio_query?text={1}&speaker={2}" -f $BaseUrl, $enc, $Speaker)
  $query = $queryResp.Content

  $wav = [IO.Path]::Combine([IO.Path]::GetTempPath(), ("voicevox_{0}.wav" -f ([guid]::NewGuid().ToString('N'))))
  try {
    Invoke-WebRequest -Method Post -UseBasicParsing -TimeoutSec $TimeoutSec `
      -ContentType 'application/json' -Body $query `
      -Uri ("{0}/synthesis?speaker={1}" -f $BaseUrl, $Speaker) -OutFile $wav | Out-Null

    if (-not (Test-Path $wav) -or (Get-Item $wav).Length -eq 0) { throw 'empty wav' }

    $player = New-Object System.Media.SoundPlayer $wav
    $player.PlaySync()
  } finally {
    Remove-Item $wav -ErrorAction SilentlyContinue
  }
}

function Speak-Sapi {
  param([string]$Text)
  Add-Type -AssemblyName System.Speech
  $synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
  # Prefer an installed Japanese voice (e.g. Haruka) so JP text is read correctly;
  # otherwise fall through to whatever the default voice is.
  $jp = $synth.GetInstalledVoices() |
    Where-Object { $_.Enabled -and $_.VoiceInfo.Culture.Name -like 'ja*' } |
    Select-Object -First 1
  if ($jp) { $synth.SelectVoice($jp.VoiceInfo.Name) }
  $synth.Speak($Text)
}

try {
  Speak-Voicevox -Text $msg -Speaker $Speaker -BaseUrl $VoicevoxUrl -TimeoutSec $TimeoutSec
} catch {
  try { Speak-Sapi -Text $msg } catch { exit 1 }
}
exit 0
