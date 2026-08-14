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

## tmux の自動起動

[dot_config/zshrc](dot_config/zshrc) の `AGENT_MODE` ガード直下に、**Linux の対話シェルで tmux へ入る**ブロックがある。SSH 経由に限らず WSL ローカルでも起動する（セッションの永続化とウィンドウ管理が目的で、これはローカルでも欲しいため）。macOS は対象外 — WezTerm 自身の mux とタブで完結しており、`ssh-window.sh` の「1 OS ウィンドウ = 1 リモートホスト」の手前で tmux を挟むとリモート側と nested になる。

判定を触るときの注意:

- **WezTerm には tmux は無い。** WezTerm が持つのは自前の mux（タブ/ペイン/ウィンドウ）で、tmux とは別実装。`tmux -CC` 連携は使っていない。つまり tmux は接続先（WSL / リモート）に 1 つあるだけで、「WezTerm 側の tmux」は存在しない。ウィンドウを閉じるときの確認ダイアログは tmux ではなく WezTerm の `window_close_confirmation`（未設定なので既定の `AlwaysPrompt`）。
- **除外経路を削らないこと。** `CLAUDECODE` / `TERM_PROGRAM=vscode` / `TERM=dumb` はいずれも、tmux を挟むと壊れる経路。`SSH_CONNECTION` 条件を外して適用範囲が全対話シェルに広がったぶん、これらのガードが実質的な安全弁になっている。
- **`exit` を無条件に書かないこと。** tmux の起動に失敗したときは素のシェルへ落とす必要がある（`if tmux ...; then exit; fi` の形）。無条件 `exit` だと tmux が動かない環境でログインできなくなる。
- **入るセッションはセッション名で決め打ちしない。** かつては `tmux new-session -A -s main` だったが、これは `main` という名前のセッションしか見ないため、素の `tmux` で作られた `0` のようなセッションが残っている端末では別途 `main` が作られてしまう（実際に発生）。現在は `tmux list-sessions` の一覧から「未 attach 優先 → 最終利用が新しい順」で 1 つ選んで attach し、1 つも無いときだけ `new-session -A -s main` に落ちる。`-A -s main` のフォールバックは、attach 対象が直前に消えたときの取りこぼし防止も兼ねている。
- 設定ファイルは [dot_config/tmux/tmux.conf](dot_config/tmux/tmux.conf) → `~/.config/tmux/tmux.conf`。この置き場所を読むのは **tmux 3.1 以降**。それより古い tmux のホストでは読まれず既定設定になるので、prefix が `C-b` のままなら真っ先にバージョンを疑う（`tmux -V`）。

## 独自コマンドと PATH（`~/.local/bin`）

自作コマンドの置き場は [dot_local/bin/](dot_local/bin/) 一箇所で、`chezmoi apply` により
`~/.local/bin`（Windows は `%USERPROFILE%\.local\bin`）へ展開される。**ここに置けば全 OS で
名前だけで呼べる**のが設計意図なので、コマンドを増やすときに PATH をいじる必要はない。

PATH を通しているのは 2 箇所だけ:

- **WSL / Linux / macOS** — [dot_config/zshrc](dot_config/zshrc) 1 行目の
  `export PATH="$HOME/.local/bin:$PATH"`。`AGENT_MODE` ガードより上（PATH を通すだけなので）。
- **Windows** — [dot_config/powershell/profile.ps1](dot_config/powershell/profile.ps1)。
  PowerShell が実際に読む `$PROFILE.CurrentUserAllHosts` は Documents 配下で、
  ローカライズ＋ OneDrive 移設を受けるパス。chezmoi は 1 ソース → 1 固定宛先なので
  apply 時にこれを解決できない。そこで実体を `~/.config/powershell/profile.ps1` に置き、
  [setup.ps1](setup.ps1) の `Install-PowerShellProfile` が実プロファイルへ dot-source の
  1 行を**追記**する（symlink ではないので開発者モード不要・OneDrive 同期と無干渉、
  かつ端末固有の行を消さない）。

触るときの注意:

- **Windows 版は `.ps1` 拡張子を落とせない**（shebang が無く、コマンド解決が拡張子ベース）。
  ただし PowerShell は PATH 上の `.ps1` を拡張子なしで解決するため、`chezmoi-merge` と
  打てば動く（`.PS1` は `PATHEXT` に無いが PowerShell 独自に見に行く。cmd.exe は不可）。
  命名は既存に合わせ、bash 版は `executable_` 付き・PowerShell 版は付けない
  （`.ps1` に実行ビットは不要なため。`claude-notify.ps1` 等と同じ）。
- **`.ps1` は `.chezmoiignore` の windows ガードに入れる。** 他 OS に配っても無害だが、
  既存の `claude-notify.ps1` / `install-voicevox-engine.ps1` と方針を揃える。
- Windows 用ラッパから **WSL のコマンドへフォールバックしない。** WSL 側の chezmoi は
  `/home/<user>` を管理するので、Windows のプロファイルではなく WSL の dotfiles を
  操作してしまう。見つからなければ 127 で止めて導入方法を出す。

この基盤の利用例は `chezmoi-merge` と、LM Studio → Ollama → opencode を繋ぐ 3 本
（`lmstudio-to-ollama` / `ollama-to-opencode` / `lmstudio-to-opencode`）。いずれも
bash 版 + PowerShell 版の対で、判定ロジックを揃えて差分を最小にしてある。詳細は
[README.md](README.md) の「独自コマンド（`~/.local/bin`）」節。

ローカル LLM 系を触るときの注意（実測で踏んだもの）:

- **`.ps1` でネイティブコマンドの stderr をリダイレクトしないこと**（`2>$null` 等）。
  Windows PowerShell 5.1 はリダイレクトされた stderr 行を `NativeCommandError` に包むため、
  `$ErrorActionPreference = 'Stop'` だと終了ステータス 0 でも例外になる。
  `ollama stop`（未ロード時）で実際に落ちた。読み捨てたいときは事前に状態を見て呼ばない。
- **PowerShell の配列スプラッティングは位置引数になる。** `@($x, '-Switch')` を
  `& script @args` に渡すと `-Switch` が 2 つ目の位置引数として渡り、束縛に失敗する。
  名前付きで渡すならハッシュテーブルスプラッティングを使う。
- **`$args` は CmdletBinding 付きスクリプトでは予約名**なので変数として使わない。
- **bash で `[ cond ] && cmd` を文として書かない。** 条件が偽だと戻り値 1 が文の値になり
  `set -e` で落ちる。`if ... fi` にする。
- **opencode の設定はコンテキスト長を「モデル名のタグ」に焼き込む方式**にしてある。
  OpenAI 互換エンドポイントに `num_ctx` を渡す口が無いため。`OLLAMA_CONTEXT_LENGTH` を
  全体に設定する案は、VRAM に収まらないモデルを CPU へ追い出すので採らない。

## WezTerm と ssh ラッパー

ターミナルエミュレータは WezTerm。設定は [dot_wezterm.lua](dot_wezterm.lua) 1 本で、`wezterm.target_triple` を見て macOS / Windows を分岐する（chezmoi は 1 ソース → 1 宛先なので、`.chezmoitemplates` ではなくファイル内分岐で解決している）。Windows では `default_domain` を WSL domain に向けてあり、PowerShell は `Ctrl+Shift+D` のランチャか `wezterm start --domain local -- powershell.exe` で出す。

[dot_config/shell/ssh-window.sh](dot_config/shell/ssh-window.sh) は、対話ログイン目的の `ssh` を `wezterm cli spawn --new-window` で別ウィンドウへ飛ばす zsh 関数。[dot_config/zshrc](dot_config/zshrc) の末尾から source している。**判定ロジックは OS 共通で、差分は spawn コマンドの組み立てだけに閉じ込める**方針。触るときの注意:

- **`wezterm cli` を叩く前に `builtin cd` でランタイムディレクトリへ移ること。** WezTerm 20240203 の Windows 版は gui ソケットを相対パスで開くため、cwd がそこでないと接続できない。そして [dot_config/zshrc](dot_config/zshrc) の独自 `cd` は移動後に `ls` を出力するので、コマンド置換の中で素の `cd` を呼ぶと出力が値に混入して壊れる。`builtin` を外さないこと。
- ラッパーは「壊れても ssh が使えなくならない」ことが最優先。判定に迷う場合・spawn に失敗した場合は必ず `command ssh "$@"` にフォールバックする。
- **ウィンドウが増える経路には歯止めを残すこと。** 疎通できないホストへの ssh は、ssh 自身がタイムアウトまで黙って粘る一方でラッパーは即座にプロンプトへ戻るため、連打や再試行ループのぶんだけウィンドウが積み上がる。しかも mux（`unix` domain / WSL domain）は GUI を閉じても生き残るので、溜まったウィンドウは次に GUI が繋いだ瞬間に一斉に開き直す（実測: 失敗した ssh ウィンドウが 8 枚 mux に residual していた）。現在は ① 同じ宛先を `SSH_WINDOW_COOLDOWN`（既定 5 秒）以内に開き直さない ② 生存ウィンドウが `SSH_WINDOW_MAX`（既定 8）に達したらその場実行に落とす ③ 失敗時のキー待ちを 5 分で打ち切る、の 3 段で止めている。台帳は `$XDG_RUNTIME_DIR`（無ければ `$TMPDIR`）の `ssh-window-<uid>.panes`。`wezterm cli list` が引けないときは「開いてよい」側に倒す（ガードのせいで ssh が開けなくなる方が困るため）。
- **キー待ちのタイムアウトに `/bin/sh` を使わないこと。** Ubuntu の `/bin/sh` は dash で `read -t` が無く、macOS の `/bin/sh` は bash 3.2 で `read -t` のタイムアウト時の戻り値が 1（bash 4 以降の `>128` ではない）。戻り値では「非対応」と「時間切れ」を区別できないので、spawn するシェルを `/bin/bash` に選んで分岐そのものを消してある。
- **`exit_behavior` はグローバル設定なので触らない。** `'CloseOnCleanExit'` にすると ssh の失敗は読めるようになるが、zsh の `exit` は直前のコマンドの終了ステータスを返すため、通常のシェルペインまで残るようになる（実測済み）。失敗した ssh ウィンドウを残す仕事は、spawn するコマンドを `sh -c` で包んで終了コード 255（= ssh 自身のエラー）のときだけキー待ちすることで実現している。
- spawn に渡す `sh -c` のスクリプト文字列に**シングルクォートを含めないこと**。zsh → `wezterm.exe`(Windows) → `wsl.exe` → `sh` と 2 回境界を越える。空白・二重引用符・日本語が保たれることは検証済み。
- **WSL では `--domain-name` を外して spawn しないこと。** domain を外すと Windows 側の `ssh.exe` が起動し、WSL の `~/.ssh/config` も鍵も参照されない。domain 指定で失敗したときに domain 無しで開き直すフォールバックは macOS / Linux 経路にのみ入れてある（そちらは既定 domain もローカルなので安全）。
- WSL では WezTerm の環境変数（`WEZTERM_UNIX_SOCKET` / `WEZTERM_PANE`）が Windows 側から渡ってこない（検証済み）。tmux の環境変数を引き直す処理は macOS 経路でのみ意味を持つ。
- 詳細と無効化方法（`SSH_NO_NEW_WINDOW=1`）は [README.md](README.md) の「WezTerm」節。

## プラットフォーム別の構成

- [setup](setup) (bash) — Ubuntu/WSL/macOS 用。`$OSTYPE` で分岐して `brew` と `apt` を使い分ける。
- [setup.ps1](setup.ps1) — Windows 専用。`Install-Terminal` で WezTerm と Alacritty を winget から入れる（未導入なら install、導入済みなら upgrade。対象ターミナルが起動中は MSI がそれを閉じてしまうためスキップ）。Alacritty だけは設定を `%APPDATA%\alacritty` にシンボリックリンクする必要がある。WezTerm は `%USERPROFILE%\.wezterm.lua` を直接読むので chezmoi が置いたままでよく、存在チェックのみ。管理者 Powershell 必須。重い処理は Unix 版 `setup` の `INSTALL_*` と同じく opt-in（`-Winget` / `-Fusion` / `-Voicevox`、または `INSTALL_WINGET=1` 等）。
  > ⚠️ **実行ポリシーは `Set-UserExecutionPolicy` が `CurrentUser` = `RemoteSigned` を入れる**（`Install-PowerShellProfile` の直前）。クライアント版 Windows の既定は `Restricted` で `.ps1` が一切走らず、プロファイルのシムが正しく追記されていても毎回「スクリプトの実行が無効」で落ちる（＝ `~/.local/bin` が PATH に入らない）。README の `-Scope Process` の Bypass は `setup.ps1` 自身のためだけの一時設定なので、これを外すと恒久対応が消える。`MachinePolicy` / `UserPolicy` が `Undefined` 以外なら GPO 管理下なので警告してスキップする（黙って成功に見せない）。
  > ⚠️ **`.ps1` に日本語コメントを書かないこと**（`setup.ps1` に限らず、このリポジトリが配る `.ps1` すべて）。Windows PowerShell 5.1 は BOM なし `.ps1` を ANSI（日本語環境では CP932）として読むため、UTF-8 の日本語がバイト単位で誤解釈され、CP932 の 2 バイト対が行末のバッククォート等を飲み込んでパースエラーになる。コメントは英語（ASCII）で書く。文字列内の `—` は後続がスペースなら実害がないので既存箇所はそのまま。
- [dot_Brewfile](dot_Brewfile) — macOS 用パッケージ一覧（wezterm / karabiner-elements などの GUI cask も含む）。
- [win_main_apps.json](win_main_apps.json) — Windows アプリ一覧（`winget export` の書式だが**中身は手入れ済みの抜粋**）。`setup.ps1 -Winget` が `winget import` で流し込む Brewfile 相当。`--no-upgrade --ignore-unavailable` 付きなので再実行は冪等（未導入のものだけ入る）。
  > ⚠️ **`winget export -o .\win_main_apps.json` で上書きしないこと。** 生の export は 22 件 → 83 件に膨れ、VCRedist / WindowsAppRuntime / .NET ランタイム / VCLibs など依存で入ったものを大量に含む（実測）。それを `import` すると新品の PC に不要なランタイムを撒く。増減は `PackageIdentifier` を手で足し引きする。参照したいときだけ `winget export -o $env:TEMP\winget-now.json` と別ファイルへ吐く。
- VSCode の `settings.json` は 3 OS 分のラッパ + 共有テンプレート構成。端末ごとに有無が変わる値（docker / im-select / 社用証明書）は `lookPath` と `stat` で存在確認してから出力し、無ければキーごと省略する。詳細は [README.md](README.md) の「VSCode ユーザー設定」。
- Colima 関連（`dot_colima/`、`Library/LaunchAgents/com.user.colima-*`、`executable_dot_wakeup`）は macOS 専用。colima 本体の自動起動は [dot_Brewfile](dot_Brewfile) の `start_service: true` が担い、生成される `homebrew.mxcl.colima.plist` は chezmoi では追跡しない。
