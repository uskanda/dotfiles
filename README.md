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

`setup.ps1` は既定ではターミナル本体（WezTerm と Alacritty）の winget インストールと
設定の配置だけを行う。本体は未導入なら `winget install`、導入済みなら `winget upgrade`
で最新に追従する（`-Winget` の一括 import は `--no-upgrade` だが、このリポジトリが設定を
配っているターミナルだけは例外として上げる）。**対象ターミナルが起動中はアップグレードを
スキップする** — MSI が実行中のターミナルを閉じてしまうため、更新したいときは一度終了
してから再実行する。Alacritty は `%APPDATA%\alacritty` へシンボリックリンクを張るが、
WezTerm は `%USERPROFILE%\.wezterm.lua` を直接読むので chezmoi が置いたままでよく、
リンクは不要（存在チェックだけ行う）。
重い処理は Unix 版 `setup` の `INSTALL_*` と同じく opt-in：

```powershell
./setup.ps1 -Winget     # win_main_apps.json のアプリを winget で一括インストール
./setup.ps1 -Fusion     # Fusion 360 MCP ブリッジ
./setup.ps1 -Voicevox   # VOICEVOX エンジン（約 1.8GB）
$env:INSTALL_WINGET=1; ./setup.ps1   # 環境変数でも指定可
```

#### Windows アプリ一覧（Brewfile 相当）

[win_main_apps.json](win_main_apps.json) が `winget export` のスナップショット。
`-Winget` を付けると `winget import --no-upgrade --ignore-unavailable` で流し込む。
`--no-upgrade` により既にインストール済みのものは触らないので、再実行しても安全。
アプリを増減したら、次のコマンドで一覧を取り直してコミットする：

```powershell
winget export -o .\win_main_apps.json
```

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
* Starshipプロンプトブラッシュアップ
* 他Rustベースプロダクト
* atuin違うかもな... fzfベースも考える
* zoxide or z
* bat
* delta new git diff
* brewfileの追加
* aptは...まあええか？
* im-select VSCode vi mode IME設定

WezTerm
-----------------------------
ターミナルエミュレータは WezTerm に寄せた（Alacritty の設定も当面残してある）。
設定は [dot_wezterm.lua](dot_wezterm.lua) の 1 本で、`wezterm.target_triple` を見て
OS ごとに分岐する。反映先は macOS / Windows とも `~/.wezterm.lua`。

### 起動先の切り替え（Windows）

既定は WSL。`wezterm.default_wsl_domains()` が `wsl -l -v` から `WSL:<distro>` という
domain を自動生成し、`default_domain` をそこに向けている（`WSL:Ubuntu` が無い端末では
先頭の WSL domain にフォールバックするので、distro 名が違っても壊れない）。

PowerShell や cmd を出したいときは:

* `Ctrl+Shift+D` — ランチャを開いて WSL / PowerShell / Command Prompt から選ぶ
* CLI から直接指定する:

```powershell
wezterm start                                    # 既定 = WSL
wezterm start --domain local -- powershell.exe   # PowerShell
```

### ssh を別ウィンドウで開く

**対話ログイン目的の `ssh` を実行すると、その場ではなく WezTerm の新規ウィンドウで
ssh が始まる。** ローカルの tmux はそのまま使いつつ、リモートでも tmux を使うため、
そのまま繋ぐと nested tmux になってしまう。「1 OS ウィンドウ = 1 リモートホスト」を
保つのが狙い。呼び出し元のペインは即座にプロンプトへ戻る。

実体は [dot_config/shell/ssh-window.sh](dot_config/shell/ssh-window.sh) の zsh 関数で、
[dot_config/zshrc](dot_config/zshrc) から source している。macOS と WSL2 で同じ 1 本を
共有し、OS 差分は spawn コマンドの組み立てだけに閉じ込めてある。

**捕まえないもの**（意図的）:

* `git` / `rsync` / `scp` / `ansible` が内部で呼ぶ ssh
  — シェル関数は対話的にコマンドラインを解釈するときにしか効かず、`execve` で直接
  呼ばれる ssh には届かない。副作用ではなく設計上の利点。
* `ssh host uptime` のようなリモートコマンド実行
* `-N` `-W` `-O` `-f` `-T` `-G` `-Q` `-V` `-s` を含む非対話用途
  （ポートフォワード、ProxyCommand、設定ダンプなど）

判定に少しでも迷ったらその場実行にフォールバックする。`wezterm` が無い端末
（ssh 先の Linux など）でも素の ssh として動く。

無効化・調整:

```bash
SSH_NO_NEW_WINDOW=1 ssh host   # 1 回だけその場で実行
export SSH_NO_NEW_WINDOW=1     # そのシェルでは常にその場で実行
unset -f ssh                   # ラッパー自体を外す

export SSH_WINDOW_DOMAIN='WSL:Debian'          # spawn 先 domain を上書き
export SSH_WINDOW_RUNTIME_DIR="$HOME/..."      # WezTerm ランタイムディレクトリを上書き
```

別ウィンドウが開かずその場で実行されてしまうときは、`SSH_WINDOW_DEBUG=1` を付けると
`wezterm cli` に渡している引数と、握りつぶしているエラーがそのまま出る。

```bash
SSH_WINDOW_DEBUG=1 ssh host
```

### Windows 固有の注意: `wezterm cli` は cwd に依存する

WezTerm 20240203 の Windows 版は gui ソケットを**相対パスで**開きにいくため、
`wezterm cli` はランタイムディレクトリ（`%USERPROFILE%\.local\share\wezterm`）を
カレントディレクトリにしていないと接続できない。別の場所から実行すると 2 秒ほど
リトライしたあと次のエラーで死ぬ:

```
ERROR wezterm > failed to connect to Socket("gui-sock-<pid>"): ...; terminating
```

`ssh-window.sh` は `wezterm cli` を叩く直前に subshell で `builtin cd` してこれを回避
している。WSL からだと Windows 側の `%USERPROFILE%` を指す必要があり、Windows の
ユーザー名は WSL のそれと一致しないため `cmd.exe` で実際に引いてキャッシュしている。

> ⚠️ ここで `cd` ではなく **`builtin cd`** を使うこと。[dot_config/zshrc](dot_config/zshrc)
> の独自 `cd` は移動後に `ls` を出力するので、コマンド置換の中で素の `cd` を呼ぶと
> ディレクトリ一覧が値に混入してパスが壊れる。

### 失敗した ssh ウィンドウだけを残す仕組み

接続に失敗したときウィンドウが即座に消えるとエラーを読めない。WezTerm には
`exit_behavior = 'CloseOnCleanExit'` があるが、これは**全ペインに効いてしまう**。
zsh の `exit` は直前のコマンドの終了ステータスをそのまま返すため、これを入れると
「失敗したコマンドの直後に `exit` した通常のシェル」までペインが残る（実測で確認）。

そこで `exit_behavior` は既定の `'Close'` のままにし、ssh ウィンドウ側だけで面倒を見る。
spawn するコマンドを `sh -c 'ssh "$@"; 255 ならキー待ち'` の形にしてあり、

* **ssh 自身のエラー（終了コード 255）** — 名前解決失敗・接続拒否・認証失敗など
  → メッセージを出してキー入力を待つ。ウィンドウが残るのでエラーが読める
* **それ以外** — リモートで普通にログアウトした場合など。直前のコマンドが失敗して
  いてもそのまま閉じる

`ssh` はリモートコマンドの終了ステータスをそのまま返し、自分自身のエラーのときだけ
255 を返す（ssh(1)）。この性質をそのまま判定に使っている。

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

### リポジトリのホスティング判定（SessionStart フック）

`mr` / `mr-main` / `mr-qa` / `mr-staging` / `fix-ci` のスキルは GitLab（`glab`）と
GitHub（`gh`）の両方に対応している。どちらを使うかをスキル呼び出しのたびに判定するのは
冗長なので、**セッション開始時に一度だけ**判定して Claude に前提知識として渡す。

* 実体: `dot_local/bin/executable_claude-hosting-hook` → `~/.local/bin/claude-hosting-hook`
* 結線: `settings.json` の `hooks.SessionStart`（stdout がそのままセッションの文脈に入る）
* 出力: `<repo-hosting>` ブロック（リポジトリ・remote・ホスト・プラットフォーム・使う CLI）
* 判定順（先勝ち）:
  1. `origin`（無ければ最初の remote）のホスト名が既知（`github.com` / `gitlab.com` 等）
  2. ホスト名に `github` / `gitlab` を含む（GitHub Enterprise・セルフホスト GitLab）
  3. `gh` / `glab` の CLI 設定（`hosts.yml` / `config.yml`）に登録済みのホスト
  4. リポジトリに `.github/workflows/` か `.gitlab-ci.yml` がある
  * どれにも当たらなければ「不明」と出力し、スキル側で判定させる
* git リポジトリでない場合・remote が無い場合は**何も出力しない**（無害）
* 前提: 通知フックと同じく、Windows では Claude Code が**フックを Git Bash で実行**できること
* 単体確認:
  ```bash
  claude-hosting-hook --plain [DIR]   # github | gitlab | unknown
  claude-hosting-hook [DIR]           # Claude に渡る文脈そのものを表示
  ```

### 反映手順（apply）

```bash
chezmoi diff          # 反映前に差分を確認
chezmoi apply ~/.claude
```

> ⚠️ `settings.json.tmpl` は雛形。`chezmoi apply` すると既存の
> `~/.claude/settings.json` を上書きするため、初回は必ず `chezmoi diff` で確認し、
> 自分の設定を取り込んでから運用すること。

VSCode ユーザー設定
-----------------------------
`settings.json` の反映先は OS ごとに違うが、chezmoi は 1 つのソースを複数の宛先へ
配れない。そこで**実体を共有テンプレートに一本化し、OS ごとの薄いラッパから
呼ぶ**構成にしている。現在の OS 以外のラッパは [.chezmoiignore](.chezmoiignore) が除外する。

| ソース                                              | 反映先                                          | OS      |
| --------------------------------------------------- | ----------------------------------------------- | ------- |
| `.chezmoitemplates/vscode-settings.json`            | （実体。直接は配られない）                      | 共通    |
| `Library/Application Support/Code/User/settings.json.tmpl` | `~/Library/Application Support/Code/User/settings.json` | macOS   |
| `dot_config/Code/User/settings.json.tmpl`           | `~/.config/Code/User/settings.json`             | Linux   |
| `AppData/Roaming/Code/User/settings.json.tmpl`      | `~/AppData/Roaming/Code/User/settings.json`     | Windows |

ラッパの中身は `{{ template "vscode-settings.json" . }}` の 1 行だけ。設定を変えるときは
**実体側だけ**を編集する。

### 端末差の吸収

端末ごとに有無が変わる値は、`lookPath` / `stat` で存在を確認してから出力する。
見つからない端末では**キーごと省略**して VSCode の既定動作に委ねるので、
docker も im-select も無い素の Linux/Windows でも壊れない。
パスは `toJson` でエスケープするため、Windows のバックスラッシュも安全。

| 値                              | 判定             | 無いとき                              |
| ------------------------------- | ---------------- | ------------------------------------- |
| `dev.containers.dockerPath`     | `lookPath docker` | キーを出さない（VSCode 既定の `docker`） |
| `dev.containers.dockerComposePath` | `lookPath docker-compose` | 同上                          |
| `vim.autoSwitchInputMethod.*`   | `lookPath im-select` かつ macOS | `enable: false`（`defaultIM` が macOS 固有の IME ID のため） |
| `claudeCode.environmentVariables` | Zscaler 証明書の `stat` | キーを出さない                  |
| `terminal.integrated.env.osx` の `NODE_EXTRA_CA_CERTS` | Zscaler 証明書の `stat` | キーを出さない |

`NODE_EXTRA_CA_CERTS` は元々 `~/.config/certs/...` と書かれていたが、**Node は `~` を
展開しない**ので効いていなかった。テンプレート側で絶対パスに展開している。

> ⚠️ **公開リポジトリである**ことに注意。`chat.tools.terminal.autoApprove` は UI からの
> 誤登録でシェル片（`true` / `do` / `[[` など）や認証情報らしき文字列が溜まりやすい。
> ソースには**コマンド名として意味のあるものだけ**を残すこと。

> ⚠️ VSCode は UI で設定を変えるたびに `settings.json` を書き換える。chezmoi はコピー
> 管理なので、**UI で変えた内容は次の `chezmoi apply` で巻き戻る**。UI で変えたら
> `chezmoi add` ではなく、実体テンプレート側に手で反映すること
> （ラッパ経由なので `chezmoi add` すると展開後の JSON でラッパが潰れる）。

### なぜ docker の絶対パスを固定するのか

VSCode は起動時にログインシェルを起こして PATH を取り込むが、これは **10 秒で
タイムアウト**する。失敗すると PATH が `/usr/bin:/bin:/usr/sbin:/sbin` だけになり、
Homebrew 配下の `docker` が見えず Dev Containers が `spawn docker ENOENT` で落ちる。
実際にこの Mac では起動ログ 10 回中 2 回で失敗しており、いずれも colima の VM が
起動・停止で負荷をかけていた時刻と一致した。絶対パス固定でこの依存を切っている。

Colima（macOS）
-----------------------------
Docker Desktop は使わず [Colima](https://github.com/abiosoft/colima) + 素の Docker CLI。
[dot_Brewfile](dot_Brewfile) の `brew "colima", start_service: true` により、
`brew bundle` を流すとログイン時に colima を自動起動する LaunchAgent
（`homebrew.mxcl.colima.plist`）が登録される。**この plist は brew services の生成物
なので chezmoi では追跡しない**（Homebrew の prefix が端末で変わるため）。

### docker.sock 復旧まわり（macOS 専用）

colima の lima は `docker.sock` の Unix ソケット forward を **VM 起動時に一度しか**
張らず、スリープ復帰やネットワーク変化で SSH マスタが張り直されると、この forward
だけが失われる（TCP ポートは復旧するのに）。結果、ソケットファイルは残るのに誰も
受けていない状態になり、ホストから docker が無応答になる。VM 内のコンテナは無傷。

対処として 2 本の LaunchAgent を常駐させている。macOS 以外へは配られない。

| ソース                                                        | 反映先                                                  | 役割                                       |
| ------------------------------------------------------------- | ------------------------------------------------------- | ------------------------------------------ |
| `dot_colima/executable_managed-docker-tunnel.sh`              | `~/.colima/managed-docker-tunnel.sh`                    | lima に頼らず自前で `docker.sock` を所有する SSH トンネル |
| `dot_colima/executable_wake-fix-docker.sh`                    | `~/.colima/wake-fix-docker.sh`                          | 死活監視して非破壊で再フォワード（冪等）   |
| `Library/LaunchAgents/com.user.colima-docker-tunnel.plist.tmpl`   | `~/Library/LaunchAgents/com.user.colima-docker-tunnel.plist`   | 上記トンネルを `KeepAlive` で常駐         |
| `Library/LaunchAgents/com.user.colima-docker-watchdog.plist.tmpl` | `~/Library/LaunchAgents/com.user.colima-docker-watchdog.plist` | 20 秒ごとに死活チェック                   |
| `executable_dot_wakeup`                                       | `~/.wakeup`                                             | sleepwatcher のウェイクフック（下記）      |

plist は `{{ .chezmoi.homeDir }}` だけをテンプレート化した**手書き**である。
`chezmoi add --autotemplate` は XML の `/` を軒並み `{{ .chezmoi.pathSeparator }}` に
置換し、さらに `StartInterval` の `20` を（gid=20 との偶然一致で）`{{ .chezmoi.gid }}` に
化けさせるので**使ってはいけない**。

`~/.wakeup` は sleepwatcher のフックだが、sleepwatcher 自体は常駐させていない
（`brew services start sleepwatcher` で有効化）。現状はウォッチドッグの 20 秒
ポーリングだけで復旧している。

```bash
launchctl list | grep colima      # 登録状況
tail -f ~/.colima/tunnel-events.log   # トンネルの切断・再接続ログ
```

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
