# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## リポジトリの目的

[chezmoi](https://www.chezmoi.io/) で管理する個人用 dotfiles。対象は WSL2 (Ubuntu) / Ubuntu / macOS。Windows は [setup.ps1](setup.ps1) で別扱い。以前の homeshick + fish 構成をリニューアルした経緯があり、現構成は zsh + zinit + starship + atuin。

## ブランチ運用

メインブランチは `master`（GitHub: `uskanda/dotfiles`）。**`master` に GitHub のブランチ保護はかかっておらず、直接コミット・直接 push してよい**。個人用 dotfiles なので、通常の変更は feature ブランチや PR を経由せず `master` に直接積む。

`/push` スキルは `gh` が未認証の端末では protected 判定を**ブランチ名のヒューリスティックにフォールバック**するため、このリポジトリの `master` を protected と誤判定して新規ブランチ作成を提案してくる。実際は unprotected なので、そのまま `master` にコミットして push すればよい。

`legacy-2015` / `legacy-2025` は旧構成のアーカイブで、触らない。`claude/*` は Claude Code が作った作業ブランチ。

## Chezmoi の命名規則（重要）

Chezmoi はファイル名のプレフィックスで配置先や挙動を決めるため、命名を崩すと黙って別の場所に展開される。

- `dot_foo` → `~/.foo`（例: [dot_Brewfile](dot_Brewfile) → `~/.Brewfile`、[dot_config/](dot_config/) → `~/.config/`）
- `symlink_dot_foo.tmpl` → テンプレートをレンダリングした先へ `~/.foo` からシンボリックリンクを張る。[symlink_dot_zshrc.tmpl](symlink_dot_zshrc.tmpl) により `~/.zshrc` は `~/.config/zshrc` へのシンボリックリンクになっており、`chezmoi apply` を再実行しなくても zsh 設定を直接編集できる。
- `private_foo` → パーミッションを厳しく（0600 相当）。[dot_config/atuin/private_config.toml](dot_config/atuin/private_config.toml) で使用。
- `*.tmpl` → Go テンプレートとしてレンダリング（`{{ .chezmoi.homeDir }}` 等の chezmoi 変数が使える）。
- [.chezmoiignore](.chezmoiignore) に列挙されたファイル（`setup`、`setup.ps1`、`win_main_apps.json`、`README.md`）は `$HOME` に展開されず、ソースディレクトリにのみ存在する。このファイル自身も **Go テンプレートとして評価される**ので、`{{ if ne .chezmoi.os "darwin" }}` で OS ごとに除外対象を変えられる。
- 先頭にドットが付かないディレクトリ（[Library/](Library/)、[AppData/](AppData/)）はそのまま `~/Library/`、`~/AppData/` になる。macOS/Windows 固有の置き場所はこれで表現している。
- [.chezmoitemplates/](.chezmoitemplates/) は共有テンプレート置き場。`{{ template "名前" . }}` で他のテンプレートから呼ぶ。**同じ内容を OS ごとに違う場所へ配りたいとき**に使う（chezmoi は 1 ソース → 複数宛先ができないため、実体をここに置き、宛先ごとの薄いラッパから呼んで、現在の OS 以外を `.chezmoiignore` で落とす）。[VSCode の settings.json](.chezmoitemplates/vscode-settings.json) がこの形。

> ⚠️ `chezmoi add --autotemplate` は使わないこと。値の一致だけを見て機械的に置換するため、XML の `/` を全部 `{{ .chezmoi.pathSeparator }}` にしたり、`StartInterval` の `20` を `{{ .chezmoi.gid }}`（gid=20 と偶然一致）に化けさせたりする。テンプレート化は手書きで、必要な箇所だけ行う。

Chezmoi の設定 ([dot_config/chezmoi/chezmoi.toml.tmpl](dot_config/chezmoi/chezmoi.toml.tmpl)) で `sourceDir = ~/dotfiles` としているため、デフォルトの `~/.local/share/chezmoi` ではなくこのリポジトリ自体がソースになっている。

[README.md](README.md) にある重要な注意: **chezmoi はシンボリックリンクではなくコピー**。`$HOME` 側で編集したものは `chezmoi add <path>` で本リポジトリへ反映し直す必要がある。例外は `~/.zshrc` のみ（`symlink_dot_zshrc.tmpl` により実シンボリックリンクになっているので `dot_config/zshrc` を直接編集可能）。

## よく使うコマンド

```bash
# 初回セットアップ (Ubuntu/WSL/macOS) — chezmoi / zsh / zinit / starship / atuin を入れて apply まで行う
./setup

# このリポジトリの内容を $HOME に反映
chezmoi apply

# apply で何が起きるかプレビュー
chezmoi diff

# $HOME 側で編集した内容をリポジトリに取り込む
chezmoi add ~/.some-file

# chezmoi 管理下でファイルを編集（ソース側を開く）
chezmoi edit ~/.some-file
```

[setup](setup) は冪等: 各ステップで `command -v` による存在チェックを行い、既にあればスキップする。再実行して問題ない。

## zshrc の AGENT_MODE

[dot_config/zshrc](dot_config/zshrc) の冒頭近くに `AGENT_MODE=1` のときだけ走る短絡処理があり、`PS1='$ '` を設定し `unalias -a` した上で、zinit / starship / atuin / カスタム `cd` / `accept-line-or-ls` バインドの読み込み前に `return` する。これは意図的な設計で、AI エージェントのシェルにはプラグインなし・プロンプト解析で事故らない・ビルトインを上書きしない素の環境を渡したいため。zshrc に新しい対話機能を足すときは必ず `AGENT_MODE` ガードの**下**に置き、エージェントセッションに漏れないようにすること。

境界の引き方は「PATH を通すだけのものは上、対話の挙動を変えるものは下」。pyenv / nvm / pnpm / antigravity / windsurf はガードより**上**にあり、エージェント用シェルからも `node` や `python` が見える。逆に ssh ラッパー・alias・zle バインドはガードより下に置く。

> ⚠️ nvm や pnpm のインストーラは各端末の zshrc へ直接追記してくる。放置すると端末ごとに乖離し、`chezmoi apply` で消える事故になる（実際に WSL 端末で発生）。見つけたら存在チェック付き・`$HOME` 化してリポジトリ側へ取り込むこと。

## WezTerm と ssh ラッパー

ターミナルエミュレータは WezTerm。設定は [dot_wezterm.lua](dot_wezterm.lua) 1 本で、`wezterm.target_triple` を見て macOS / Windows を分岐する（chezmoi は 1 ソース → 1 宛先なので、`.chezmoitemplates` ではなくファイル内分岐で解決している）。Windows では `default_domain` を WSL domain に向けてあり、PowerShell は `Ctrl+Shift+D` のランチャか `wezterm start --domain local -- powershell.exe` で出す。

[dot_config/shell/ssh-window.sh](dot_config/shell/ssh-window.sh) は、対話ログイン目的の `ssh` を `wezterm cli spawn --new-window` で別ウィンドウへ飛ばす zsh 関数。[dot_config/zshrc](dot_config/zshrc) の末尾から source している。**判定ロジックは OS 共通で、差分は spawn コマンドの組み立てだけに閉じ込める**方針。触るときの注意:

- **`wezterm cli` を叩く前に `builtin cd` でランタイムディレクトリへ移ること。** WezTerm 20240203 の Windows 版は gui ソケットを相対パスで開くため、cwd がそこでないと接続できない。そして [dot_config/zshrc](dot_config/zshrc) の独自 `cd` は移動後に `ls` を出力するので、コマンド置換の中で素の `cd` を呼ぶと出力が値に混入して壊れる。`builtin` を外さないこと。
- ラッパーは「壊れても ssh が使えなくならない」ことが最優先。判定に迷う場合・spawn に失敗した場合は必ず `command ssh "$@"` にフォールバックする。
- **`exit_behavior` はグローバル設定なので触らない。** `'CloseOnCleanExit'` にすると ssh の失敗は読めるようになるが、zsh の `exit` は直前のコマンドの終了ステータスを返すため、通常のシェルペインまで残るようになる（実測済み）。失敗した ssh ウィンドウを残す仕事は、spawn するコマンドを `sh -c` で包んで終了コード 255（= ssh 自身のエラー）のときだけキー待ちすることで実現している。
- spawn に渡す `sh -c` のスクリプト文字列に**シングルクォートを含めないこと**。zsh → `wezterm.exe`(Windows) → `wsl.exe` → `sh` と 2 回境界を越える。空白・二重引用符・日本語が保たれることは検証済み。
- **WSL では `--domain-name` を外して spawn しないこと。** domain を外すと Windows 側の `ssh.exe` が起動し、WSL の `~/.ssh/config` も鍵も参照されない。domain 指定で失敗したときに domain 無しで開き直すフォールバックは macOS / Linux 経路にのみ入れてある（そちらは既定 domain もローカルなので安全）。
- WSL では WezTerm の環境変数（`WEZTERM_UNIX_SOCKET` / `WEZTERM_PANE`）が Windows 側から渡ってこない（検証済み）。tmux の環境変数を引き直す処理は macOS 経路でのみ意味を持つ。
- 詳細と無効化方法（`SSH_NO_NEW_WINDOW=1`）は [README.md](README.md) の「WezTerm」節。

## プラットフォーム別の構成

- [setup](setup) (bash) — Ubuntu/WSL/macOS 用。`$OSTYPE` で分岐して `brew` と `apt` を使い分ける。
- [setup.ps1](setup.ps1) — Windows 専用。`Install-Terminal` で WezTerm と Alacritty を winget から入れる（未導入なら install、導入済みなら upgrade。対象ターミナルが起動中は MSI がそれを閉じてしまうためスキップ）。Alacritty だけは設定を `%APPDATA%\alacritty` にシンボリックリンクする必要がある。WezTerm は `%USERPROFILE%\.wezterm.lua` を直接読むので chezmoi が置いたままでよく、存在チェックのみ。管理者 Powershell 必須。重い処理は Unix 版 `setup` の `INSTALL_*` と同じく opt-in（`-Winget` / `-Fusion` / `-Voicevox`、または `INSTALL_WINGET=1` 等）。
  > ⚠️ **このファイルに日本語コメントを書かないこと**。Windows PowerShell 5.1 は BOM なし `.ps1` を ANSI（日本語環境では CP932）として読むため、UTF-8 の日本語がバイト単位で誤解釈され、CP932 の 2 バイト対が行末のバッククォート等を飲み込んでパースエラーになる。コメントは英語（ASCII）で書く。文字列内の `—` は後続がスペースなら実害がないので既存箇所はそのまま。
- [dot_Brewfile](dot_Brewfile) — macOS 用パッケージ一覧（wezterm / karabiner-elements などの GUI cask も含む）。
- [win_main_apps.json](win_main_apps.json) — Windows アプリ一覧（`winget export` の出力）。`setup.ps1 -Winget` が `winget import` で流し込む Brewfile 相当。`--no-upgrade --ignore-unavailable` 付きなので再実行は冪等（未導入のものだけ入る）。一覧の更新は `winget export -o .\win_main_apps.json` を手動で実行する。
- VSCode の `settings.json` は 3 OS 分のラッパ + 共有テンプレート構成。端末ごとに有無が変わる値（docker / im-select / 社用証明書）は `lookPath` と `stat` で存在確認してから出力し、無ければキーごと省略する。詳細は [README.md](README.md) の「VSCode ユーザー設定」。
- Colima 関連（`dot_colima/`、`Library/LaunchAgents/com.user.colima-*`、`executable_dot_wakeup`）は macOS 専用。colima 本体の自動起動は [dot_Brewfile](dot_Brewfile) の `start_service: true` が担い、生成される `homebrew.mxcl.colima.plist` は chezmoi では追跡しない。
