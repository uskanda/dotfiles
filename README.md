uskanda's dotfiles
============================

作業中

このディレクトリ全体はChezmoi管理下である。
Chezmoiのネーミングルールに反するものは無視されるのでセットアップスクリプトなどもここにそのまま置く。

WSL2(Ubuntu)/Ubuntu/MacOS対応予定。

installation
-----------------------------
### Windows
* Powershellを管理者権限で実行

> Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
> ./setup.ps1

### Ubuntu, WSL

```bash
./setup
```

リニューアル点
-----------------------------
* fishをやめてzshベースで再構成
* dotfiles管理をhomeshickからchezmoiへ移行

ToDo
-----------------------------
* xcode-select --installの追加
* Terminal Multiplexer選定 Zellij、prefix連打でペイン動くのできないっぽい？
* ターミナルエミュレータ選定 Alacritty or Wezterm Wezterm寄り
* Starshipプロンプトブラッシュアップ
* 他Rustベースプロダクト
* atuin違うかもな... fzfベースも考える
* zoxide or z
* bat
* delta new git diff
* brewfileの追加
* aptは...まあええか？
* wezterm muxまわり設定
* im-select VSCode vi mode IME設定

Claude Code 設定 (~/.claude)
-----------------------------
Claude Code のユーザー設定を chezmoi で複数端末に共有する。
方針は **allowlist**：自分で書いた設定だけを追跡し、認証情報・セッション履歴・
ランタイム状態は **絶対にコミットしない**。

### レイアウト（ソース命名規則）

| ソース（このリポジトリ）            | 反映先                         | 備考                       |
| ----------------------------------- | ------------------------------ | -------------------------- |
| `dot_claude/`                       | `~/.claude/`                   | `dot_` → 先頭ドット        |
| `dot_claude/settings.json.tmpl`     | `~/.claude/settings.json`      | テンプレート（後述）       |
| `dot_claude/CLAUDE.md`              | `~/.claude/CLAUDE.md`          | ローカルで `chezmoi add`   |
| `dot_claude/commands/`              | `~/.claude/commands/`          | ローカルで `chezmoi add`   |
| `dot_claude/agents/`                | `~/.claude/agents/`            | ローカルで `chezmoi add`   |
| `dot_claude/skills/`                | `~/.claude/skills/`            | ローカルで `chezmoi add`   |

このクラウド/CI 環境からは実際の `~/.claude` が見えないため、コミットされているのは
`settings.json.tmpl`（無難な既定値の雛形）のみ。`CLAUDE.md` や `commands/` などの
実ファイルは、各自のマシンで下記コマンドを実行してソースへ取り込むこと。

```bash
# 自分の実ファイルをソースへ取り込む（.chezmoiignore は自動で適用される）
chezmoi add ~/.claude/CLAUDE.md
chezmoi add ~/.claude/commands ~/.claude/agents ~/.claude/skills

# settings.json をテンプレートとして取り込み直したい場合
chezmoi add --template ~/.claude/settings.json
```

`chezmoi add ~/.claude` とディレクトリごと渡しても、除外対象（下表）は
`ignoring ...` と表示されて取り込まれないことを、利用中の chezmoi で確認済み。

### 追跡する / 除外する

* **追跡**: `settings.json`, `CLAUDE.md`, `commands/`, `agents/`, `skills/`,
  （任意で）プラグイン設定
* **除外**（`.chezmoiignore` に記載。ターゲットパス＝`$HOME` 相対で評価される）
  * `.claude/.credentials.json` … 認証トークン。**秘密。絶対にコミットしない**
  * `.claude/settings.local.json` … 端末ローカル上書き
  * `.claude/projects/` … セッション履歴（巨大・端末固有）
  * `.claude/todos/`, `.claude/shell-snapshots/`, `.claude/statsig/`,
    `.claude/history.jsonl`, `.claude/ide/` … ランタイム状態・キャッシュ

### settings.json のテンプレート化と端末固有の上書き

端末差分が出やすい `model` は `settings.json.tmpl` でテンプレート化している。
既定値は `claude-sonnet-4-6`。端末ごとに変えたいときは、その端末の
`~/.config/chezmoi/chezmoi.toml`（chezmoi のローカル設定、リポジトリには入らない）に
データを書く：

```toml
[data.claude]
model = "claude-opus-4-8"
```

`dig` で未設定時は既定値にフォールバックするため、データ未定義の端末でも安全に描画される。

### 反映手順（apply）

```bash
chezmoi diff          # 反映前に差分を確認
chezmoi apply ~/.claude
```

> ⚠️ `settings.json.tmpl` は雛形。`chezmoi apply` すると既存の
> `~/.claude/settings.json` を上書きするため、初回は必ず `chezmoi diff` で確認し、
> 自分の設定を取り込んでから運用すること。

### skill: tech-writing-ja（日本語技術文書の規約）

Claude が生成する日本語の冗長さと、未定義の専門用語を減らすための規約。
`dot_claude/skills/tech-writing-ja/` にある。`chezmoi apply` で反映される。

* `SKILL.md` … 規約本体（`W-*` 54項目）と自己校閲手順
* `references/redundancy.md` … 冗長表現の置換表
* `references/terminology.md` … 用語の扱いと用語集の作り方（`W-406`〜`W-408`）
* `references/openspec.md` … OpenSpec 成果物向け（`OS-*` 30項目）
* `references/code-comments.md` … ソースコメント向け（`C-*` 27項目）

skill は発火したときだけ効くため、常時効かせたい最小規約は `~/.claude/CLAUDE.md` へ
手で追記する。追記する本文と手順は `docs/tech-writing/CLAUDE.md.snippet.md` にある。
`CLAUDE.md` を自動反映しないのは、`chezmoi apply` が既存の記述を上書きするためである。

検討の経緯、出典とライセンス、決定事項は `docs/tech-writing/` に残してある。
textlint による機械検査は opt-in であり、まだ導入していない。

VOICEVOX エンジン（任意）
-----------------------------
`claude-notify`（Claude Code の Stop/Notification フック）は、`localhost:50021` で
VOICEVOX エンジンが動いていれば日本語 TTS で読み上げる。エンジンが無い場合は
OS 標準の TTS（macOS は `say`、Windows は SAPI5）へ自動フォールバックするため、
**インストールは任意**。`install-voicevox-engine` は macOS 専用。Windows で声を
統一したい場合は VOICEVOX アプリ（エンジンが `:50021` で起動）を各 PC に導入する。

約 1.8GB のダウンロードを伴うため、`./setup` ではデフォルト無効。有効化するには:

```bash
INSTALL_VOICEVOX=1 ./setup        # setup の一部として
# もしくは単体で（冪等・再実行可）
install-voicevox-engine           # ~/.local/bin に配置済み
install-voicevox-engine uninstall # 停止して削除
```

インストーラ（`dot_local/bin/executable_install-voicevox-engine`）の挙動:

* エンジン（macOS arm64/x64）を GitHub Releases から取得し `7zz` で展開
* `~/Applications/voicevox_engine/` に配置
* `~/Library/LaunchAgents/com.voicevox.engine.plist` を生成し `launchctl` で常駐起動
  （`KeepAlive` 付き＝ログイン時/異常終了時に自動復帰）
* 既に `:50021` が応答していれば何もしない

発話者は `claude-notify` の `VOICEVOX_SPEAKER`（既定 `8` = 春日部つむぎ）で切替。
インストール済みスタイルの一覧は次で確認できる:

```bash
curl -s http://localhost:50021/speakers | python3 -m json.tool
```

devcontainer / SSH からの発話（任意）
-----------------------------
devcontainer や SSH 先で Claude Code を動かしても、音声は**手元の Mac で再生**する必要が
ある（リモート側にスピーカーは無い）。そこで Mac に通知デーモンを常駐させ、リモートの
`claude-notify` がメッセージ本文だけを Mac に渡して、Mac 側で VOICEVOX 合成＋afplay する。

```
remote claude-notify ──案1──> Mac daemon(:50090) ──> VOICEVOX(:50021) + afplay
                     └─案2──> ntfy(self-host) ──> Mac subscriber ──> 同上
```

* **案1（既定）**: Mac の `claude-notify-daemon` に直接 POST
  * devcontainer (Colima): コンテナから `http://host.docker.internal:50090`（`192.168.5.2`）で到達。実測で確認済み
  * SSH: `~/.ssh/config` の該当ホストに `RemoteForward 50090 127.0.0.1:50090` を足し、リモートからは `http://localhost:50090` に届く
* **案2（フォールバック・後日）**: 案1 が届かない出先/別NW 用。セルフホスト ntfy 経由。
  `CLAUDE_NTFY_URL` / `CLAUDE_NTFY_TOPIC` が**空なら何も送らずスキップ**（未構築でも無害）

### セットアップ（Mac 受信側）

```bash
INSTALL_NOTIFY_DAEMON=1 ./setup     # setup の一部として（案1デーモンを常駐化）
# もしくは単体で
claude-notify-daemon install        # com.claude.notify-daemon を常駐起動
claude-notify-daemon uninstall
claude-notify-ntfy-sub install      # 案2の購読常駐（ntfy未設定なら自動でno-op）
```

### 設定値（秘密はリポジトリに入れない）

`~/.config/claude-notify/config.env` は `config.env.tmpl` から生成され、値は各端末の
`~/.config/chezmoi/chezmoi.toml` に書く（`settings.json` と同じ方式）:

```toml
[data.claudeNotify]
token     = "長いランダム文字列"          # 案1の共有トークン（Mac/リモート両方に同値）
ntfyUrl   = "https://ntfy.example.com"   # 案2（後日）。空なら案2スキップ
ntfyTopic = "claude-xxxxxxxx"
ntfyToken = ""
```

> ⚠️ デーモンは Colima から届くよう `0.0.0.0:50090` で待受するため**同一LANに公開される**。
> 必ず `token` を設定すること（設定すると `/notify` に `X-Notify-Token` ヘッダを要求）。
> トークンは Mac（受信）とリモート（送信）の両方の `chezmoi.toml` に同じ値を入れて
> `chezmoi apply` し、Mac 側は `claude-notify-daemon install` で再読込する。
> （Windows 受信側の既定待受は `127.0.0.1:50090`＝ローカル/SSH トンネル専用で LAN 非公開。）

Windows での発話（env1 / env2 / env3）
-----------------------------
「目の前のマシン＝音を鳴らすシンク」という Mac と同じ原則で Windows でも鳴らす。
発話の実体は Windows 共通の `claude-notify.ps1`（VOICEVOX→SAPI5）で、3 環境がこれを共有する。

```
env1 native Win (Git Bash) : hook → claude-notify(bash) → powershell.exe → claude-notify.ps1
env2 WSL2                  : hook → claude-notify(bash, WSL検出) → powershell.exe(interop) → 〃
env3 Win ← SSH ← Linux     : hook → claude-notify(bash, SSH検出) → :50090 POST → claude-notify-daemon → 〃
```

* **前提**: Claude Code が**フックを Git Bash で実行**できること（Git for Windows を導入。
  見つからない場合は `CLAUDE_CODE_GIT_BASH_PATH` で明示）。`chezmoi apply` で
  `~/.local/bin/`（＝`%USERPROFILE%\.local\bin`）にスクリプト一式を配置する。
* **依存**: Git for Windows（`curl`/`base64`/`cygpath` 同梱）、**Python 3**（フック/デーモンの
  JSON 処理。`python3` が無くても `python`/`py -3` を自動使用）。VOICEVOX は任意（無ければ SAPI）。
* **env1（ネイティブ）**: `chezmoi apply` だけで完了。フックは Git Bash で動き、その場で発話。
* **env2（WSL2）**: WSL 内で `chezmoi apply`。`claude-notify` が WSL を検出し `powershell.exe`
  経由で Windows 側 `claude-notify.ps1` を起動（デーモン/ネットワーク不要）。
  Win11 の WSLg なら `paplay` の通知音はそのまま Windows ミキサーへ流れる。
* **env3（SSH 受信側＝Windows）**: サーバ側は無改修。Windows で受信デーモンを常駐し、
  Windows の SSH 設定（`~/.ssh/config` か VSCode Remote-SSH）に
  `RemoteForward 50090 127.0.0.1:50090` を足す。`token` はサーバ/Windows 両方の
  `chezmoi.toml` に同値。**案2 の ntfy 購読はデーモンに内包**（起動項目 1 本で案1+案2）。

```bat
:: Windows（Git Bash でも cmd/PowerShell でも可）。Python が PATH にある前提。
python %USERPROFILE%\.local\bin\claude-notify-daemon install    :: スタートアップ常駐＋起動
python %USERPROFILE%\.local\bin\claude-notify-daemon uninstall  :: 解除
```
常駐は `%APPDATA%\…\Startup\claude-notify-daemon.vbs`（`pythonw` を隠し起動）。

学び
-----------------------------
* chezmoiってsymlinkでなくてコピーなのね
* コピー先ファイルの変更はchezmoi addで再反映する
* `.chezmoiignore` は `chezmoi add` 時にも効く（マッチは取り込まれない）

このdotfiles/setupで対象にしないこと
-----------------------------
* Nerd Fonts適用のフォントのビルド・インストール
  現在はUDEV Gothicを使っており、Nerd Fonts適用のUDEV Gothicを使う前提
* アプリケーション側で同期設定のあるアプリ
  * VSCode

やったけど未反映
---------------------
brew tap daipeihust/tap
brew install im-select
