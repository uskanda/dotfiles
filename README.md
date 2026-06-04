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

VOICEVOX エンジン（任意）
-----------------------------
`claude-notify`（Claude Code の Stop/Notification フック）は、`localhost:50021` で
VOICEVOX エンジンが動いていれば日本語 TTS で読み上げる。エンジンが無い場合は
macOS 標準の `say` 音声へ自動フォールバックするため、**インストールは任意**。

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
