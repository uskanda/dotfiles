# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## リポジトリの目的

[chezmoi](https://www.chezmoi.io/) で管理する個人用 dotfiles。対象は WSL2 (Ubuntu) / Ubuntu / macOS。Windows は [setup.ps1](setup.ps1) で別扱い。以前の homeshick + fish 構成をリニューアルした経緯があり、現構成は zsh + zinit + starship + atuin。

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

## プラットフォーム別の構成

- [setup](setup) (bash) — Ubuntu/WSL/macOS 用。`$OSTYPE` で分岐して `brew` と `apt` を使い分ける。
- [setup.ps1](setup.ps1) — Windows 専用。Alacritty 設定を `%APPDATA%\alacritty` にシンボリックリンクとして配置する。管理者 Powershell 必須。
- [dot_Brewfile](dot_Brewfile) — macOS 用パッケージ一覧（wezterm / karabiner-elements などの GUI cask も含む）。
- [win_main_apps.json](win_main_apps.json) — Windows アプリ一覧。現状どのスクリプトからも使われていない。
- VSCode の `settings.json` は 3 OS 分のラッパ + 共有テンプレート構成。端末ごとに有無が変わる値（docker / im-select / 社用証明書）は `lookPath` と `stat` で存在確認してから出力し、無ければキーごと省略する。詳細は [README.md](README.md) の「VSCode ユーザー設定」。
- Colima 関連（`dot_colima/`、`Library/LaunchAgents/com.user.colima-*`、`executable_dot_wakeup`）は macOS 専用。colima 本体の自動起動は [dot_Brewfile](dot_Brewfile) の `start_service: true` が担い、生成される `homebrew.mxcl.colima.plist` は chezmoi では追跡しない。
