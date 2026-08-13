# Windows VoiceVox / claude-notify 対応 — 進捗と残タスク

最終更新: 2026-06-05

Claude Code の処理完了/確認時の「発声」(VoiceVox TTS) を、Mac に加えて
Windows 系3環境でも実現する作業の進捗メモ。設計・使い方の本文は
[`README.md`](README.md) の「Windows での発話」節を参照。

## 全体方針

「目の前のマシン＝音を鳴らすシンク」。全環境が**同一の bash フック連鎖**で動き、
OS 差は `claude-notify` 内部 ＋ Windows 発声器 `claude-notify.ps1` ＋ デーモンに閉じる。

| 環境 | フック実行場所 | 発声経路 |
|---|---|---|
| env1 ネイティブWin (Git Bash) | Windows | `claude-notify`(bash) → `powershell.exe` → `claude-notify.ps1` |
| env2 WSL2 | WSL(Linux) | `claude-notify`(bash, WSL検出) → `powershell.exe`(interop) → 〃 |
| env3 Win ← SSH ← Linux | サーバ(Linux) | `claude-notify`(bash, SSH検出) → `:50090` POST → `claude-notify-daemon` → 〃 |

発声の実体 `claude-notify.ps1` は **VoiceVox(:50021) → SAPI5** の二段（Mac の VoiceVox→say と対称）。

## 完了（実装・コミット済み）

コミット: `8c444c9`(発話) / `bf0919a`(デーモン) / `baa8c06`(フック・結線・docs) / `a81c2ca`(権限sync)。
いずれも `origin/master` に push 済み。

- [x] **`claude-notify.ps1`（新規）** — Windows 発声器。`-B64`(base64 UTF-8) で受け取り、
      VoiceVox 合成→`SoundPlayer.PlaySync`→失敗時 `System.Speech`(SAPI5, 日本語音声優先)。
      env1/2/3 が共有する単一実装。
- [x] **`claude-notify`（bash）** — `uname` 分岐に MINGW/MSYS/CYGWIN(env1)・WSL2(env2) を追加。
      `win_speak`/`to_win_path`(cygpath/wslpath)/`is_wsl`/`local_fallback` ヘルパ。
      判定順は container/SSH → WSL → bare（WSLバックエンドのdevcontainer誤検知を回避）。
- [x] **`claude-notify-daemon`（py）** — `speak()` を OS 分岐（nt→ps1）。案2 ntfy 購読を
      デーモンに内包（Windowsのみ）。Windows 常駐＝スタートアップ VBS(`pythonw` 隠し起動)。
      Windows 既定 bind=`127.0.0.1`（LAN非公開・FW警告回避）。
- [x] **`claude-notify-hook` / `-nag`** — `python3`→`python`→`py -3` リゾルバ（Git Bash 対策）。
- [x] **`settings.json.tmpl`** — Windows ではフックパスを `~/.local/bin/...`(Git Bash向け)に。
- [x] **`README.md`** — Windows 発話(env1/2/3) 節、VOICEVOX 節に SAPI フォールバック注記。
- [x] **Linux 上で検証可能な範囲はテスト済み** — `bash -n`/`py_compile`/デーモン HTTP
      (`/health`,`/notify`)/フックチェーン E2E（done・notification・stop、nag起動停止）/
      テンプレ描画（有効JSON・既存パス不変）。

## 仮採用した設計判断（必要なら見直し可）

- ntfy(案2) = **デーモン内包**（起動項目1本で案1+案2。Mac は従来どおり別 LaunchAgent）。
- Windows 常駐 = **スタートアップ VBS**（管理者不要・タスクスケジューラ/NSSM 不使用）。
- Windows デーモン bind = **`127.0.0.1`**（env1ローカル+env3 RemoteForward で十分）。
- VoiceVox の Windows 自動導入は **しない**（手動で VOICEVOX アプリ＝`:50021`。無ければ SAPI）。
- env2(WSL2) は **interop 方式**（`powershell.exe` 経由。デーモン/ネットワーク不要）。
- メッセージは **base64(UTF-8)** で受け渡し（境界の文字化け回避）。

## 残タスク（★実機テストが必要 — このLinuxではWindows/pwsh/WSL未検証）

### env1: ネイティブ Windows + Git Bash
- [ ] `chezmoi apply` で `~/.local/bin/` 一式配置（`claude-notify.ps1` 含む）
- [ ] **Python 3** を PATH に（hook/daemon の JSON 処理。無くても `python`/`py -3` で動くが要確認）
- [ ] Claude Code がフックを Git Bash で実行できること（見つからない時は `CLAUDE_CODE_GIT_BASH_PATH`）
- [ ] 実際に処理完了/確認で発話するか確認
- [ ] （任意）VOICEVOX アプリ起動で声を統一、無い場合 SAPI 発話を確認

### env2: WSL2
- [ ] WSL 内で `chezmoi apply`
- [ ] `claude-notify "テスト"` 単体で `powershell.exe` interop → ps1 発話を確認
- [ ] ★**懸念**: `wslpath -w` の UNC パス（`\\wsl.localhost\...`）から `-File` で ps1 を
      実行できるか（`-ExecutionPolicy Bypass` で UNC 実行/警告を回避できる想定だが未検証）。
      ダメなら `-EncodedCommand` 方式へ切替
- [ ] Win11 WSLg なら `paplay` のチャイムが Windows ミキサーへ流れることを確認

### env3: Windows ← SSH ← Linux サーバ
- [ ] サーバ側は**無改修**（既存 `claude-notify` が `:50090` へ POST）
- [ ] Windows で `python %USERPROFILE%\.local\bin\claude-notify-daemon install`（VBS常駐＋起動）
- [ ] Windows の SSH 設定（`~/.ssh/config` か VSCode Remote-SSH）に
      `RemoteForward 50090 127.0.0.1:50090`
- [ ] `token` をサーバ/Windows 両方の `chezmoi.toml` に同値
- [ ] サーバから発話が手元の Windows で鳴るか確認
- [ ] （任意）出先用に案2 ntfy（`CLAUDE_NTFY_URL`/`TOPIC`）設定 → デーモン内蔵購読で受信

### `claude-notify.ps1` の実行時検証（未実行＝手動精読のみ）
- [ ] VoiceVox `audio_query`(.Content そのまま)→`synthesis`→WAV 取得の流れ
- [ ] `System.Media.SoundPlayer.PlaySync()` が VoiceVox WAV を再生できるか
- [ ] SAPI フォールバックで日本語音声（Haruka 等 `ja*`）が選択され読み上げるか
- [ ] `powershell.exe`（Windows PowerShell 5.1）前提でアセンブリ
      (`System.Media`/`System.Speech`) が利用可能か

### 既知のリスク / 監視ポイント
- WSL の UNC スクリプト実行（上記 env2 懸念）
- 日本語引数の文字化け → base64 で緩和済み
- `python3` 不在 → `python`/`py -3` リゾルバで緩和済み
- Windows Firewall → bind `127.0.0.1` で緩和済み
- 発話者 ID（`VOICEVOX_SPEAKER` 既定 `8`=春日部つむぎ）の Windows VoiceVox 側スタイル有無

## 関連ファイル

- `dot_local/bin/claude-notify.ps1` — Windows 発声器（新規）
- `dot_local/bin/executable_claude-notify` — OS 分岐ディスパッチャ
- `dot_local/bin/executable_claude-notify-daemon` — 受信デーモン（案1+案2、Windows常駐）
- `dot_local/bin/executable_claude-notify-hook` / `-nag` — フック本体（py リゾルバ）
- `dot_claude/settings.json.tmpl` — フック結線（Windows パス分岐）
- `README.md` — 利用者向けセットアップ手順
