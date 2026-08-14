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

1 行目の `-Scope Process` は**この `setup.ps1` を走らせるためだけ**のブートストラップ。
恒久的な設定は `setup.ps1` 側（`Set-UserExecutionPolicy`）が `CurrentUser` スコープに
`RemoteSigned` を入れて行う。詳細は
[実行ポリシー](#実行ポリシーrestricted-のままだとプロファイルが読めない) を参照。

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

[win_main_apps.json](win_main_apps.json) が `winget export` の書式で書いた**手入れ済みの一覧**。
`-Winget` を付けると `winget import --no-upgrade --ignore-unavailable` で流し込む。
`--no-upgrade` により既にインストール済みのものは触らないので、再実行しても安全。

> ⚠️ **`winget export -o .\win_main_apps.json` で上書きしないこと。** このファイルは
> 生の export ではなく、そこから「自分で入れたいアプリ」だけを残した一覧。実際に
> 取り直すと 22 件 → 83 件に膨れ、VCRedist / WindowsAppRuntime / .NET ランタイム /
> VCLibs といった**依存で勝手に入ったものが大量に混ざる**（実測）。それを `import`
> すると新品の PC に不要なランタイムまで撒くことになる。

アプリを増減したいときは、**該当の `PackageIdentifier` を手で足し引きする**のが基本。
一覧を眺めて拾いたい場合は、別ファイルへ吐いてから差分を見る：

```powershell
winget export -o $env:TEMP\winget-now.json     # 作業用。リポジトリには上書きしない
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

開いたウィンドウには `ssh: <host>` というタブタイトルが付き、`format-window-title`
イベントで **OS ウィンドウのタイトルにも同じものが出る**。Windows のタスクバーや
Alt+Tab、macOS の Mission Control でどれがどのホストか判別できる。

タブが 1 枚のときはタブバーを隠す設定にしてあるため、ssh ウィンドウ（= タブ 1 枚）
ではタブバー上のタイトルは見えない。判別は上の OS ウィンドウタイトル側が担う。

なお Windows 側からは WSL の中で動いているプロセスが見えず、素のままだとどの
ウィンドウも `wslhost.exe`（interop のホストプロセス名）と表示されてしまう。
ドメイン名で判定して `WSL` と出すようにしてある。

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

SSH_WINDOW_DUP=1 ssh host      # 既存ウィンドウがあっても別ウィンドウで開く
export SSH_WINDOW_MAX=8        # 同時に開いておける ssh ウィンドウ数 (0 で無制限)
```

### ウィンドウが増えすぎないための歯止め

**疎通できないホストに ssh すると、放っておけばウィンドウが際限なく増える。**
ssh は接続を諦めるまで（既定で 1 分以上）黙って粘るのに、ラッパーは spawn した
時点でプロンプトへ戻るので、「開かなかったように見えて叩き直す」たびに 1 枚ずつ
積み上がる。さらに悪いことに、mux（`unix` domain / WSL domain）は GUI を閉じても
生き残るため、溜まったウィンドウは**次に GUI が繋いだ瞬間にまとめて開き直す**。
実際に mux へ 9 枚の ssh ウィンドウが residual していたことがある。

歯止めは 3 つ:

1. **同じ宛先のウィンドウが生きている間は開き直さない** — 2 枚目を開かず、既存の
   ウィンドウを前面に出す。もともと「1 OS ウィンドウ = 1 リモートホスト」が狙いの
   仕組みなので、これが既定の挙動。意図して 2 セッション張りたいときは
   `SSH_WINDOW_DUP=1 ssh host`。台帳は `$XDG_RUNTIME_DIR`（無ければ `$TMPDIR`）の
   `ssh-window-<uid>.panes` で、参照のたびに `wezterm cli list` と突き合わせて
   閉じ済みの行を落とす。
   既存ウィンドウが「ssh が失敗してキー待ち」状態のときは、**閉じてから開き直す**。
   前面に出すだけだと再試行できず、残したまま開くと失敗のたびに 1 枚ずつ増える。
   入れ替えなら何度失敗しても宛先あたり 1 枚に収まる。判定は hold スクリプトが
   行頭に出す `[ssh-window:failed]` マーカー（日本語メッセージは `get-text` で
   桁折り返しされ grep が当たらないので ASCII の目印を使う）。
2. **枚数の上限** — 生きている ssh ウィンドウが `SSH_WINDOW_MAX`（既定 8）に達したら
   spawn せずその場で実行する。宛先が毎回違う暴走もここで止まる。前面で ssh が
   走るぶん、次の 1 回が勝手に始まらないのも狙い。
3. **エラー表示の自動クローズ** — 失敗したウィンドウのキー待ちは 5 分で打ち切って
   閉じる。無期限に待つと mux に永久に残るため（上の residual の正体）。

> ⚠️ **「n 秒以内の再実行だけ抑止する」では足りない**（実測）。当初は 5 秒の
> クールダウンで止めるつもりだったが、人間の叩き直しは数秒〜十数秒間隔なので
> 素通りし、7 秒間隔の 3 連打で普通に 3 枚開いた。上限の枚数まで積み上がるだけで
> 歯止めになっていない。生きている限り開かない、が正しい。

### 増殖の真犯人: mux への自己接続 (`--domain-name unix`)

**macOS / Linux では `wezterm cli spawn` に `--domain-name` を渡してはいけない。**

`unix` domain のペインでは `WEZTERM_UNIX_SOCKET` が **mux サーバ自身**のソケットを
指す。そこへ `--domain-name unix` で spawn を頼むと、mux は「自分自身の unix domain
へ接続する」動きになる。実測した挙動:

* spawn 1 回で pane id が 2 → 7 まで飛ぶ（内部で複数ペインが作られる）
* `wezterm cli list` に**実体のないゴースト**が残る。`kill-pane` しても
  `Error: no such pane` で消せない
* GUI が繋いだ瞬間にゴーストぶんのウィンドウが**一斉に開く**
* GUI が繋がっていない mux に対しては spawn が**返ってこない**（2 分待っても終わらず、
  そのまま mux 自体が落ちることもある）

これが「ssh を叩くたびにウィンドウが大量に出る」の主因だった。domain を省けば
「今いるサーバの既定 domain」に開くので、mux のペインからなら mux の中に、GUI
ローカルのペインからなら GUI の中に、正しく 1 枚だけ開く。

WSL だけは逆で、Windows 側の GUI に対して `--domain-name WSL:<distro>` を明示しないと
Windows の `ssh.exe` が起動してしまうため、指定を残してある。

> ⚠️ **溜まったゴーストは mux を落とすまで消えない。** `wezterm cli kill-pane` は
> 効かず、GUI を閉じても mux は生き残る。`pkill -f wezterm-mux-server`（SIGTERM で
> 落ちる）で mux ごと終了させると、その mux 上のセッションは全部消えるかわりに
> 一掃できる。GUI もぶら下がっているので一緒に終了する。
> なお **pkill が効いていないように見えるのは、GUI を開き直すと新しい mux が
> 作られ、そこにまた溜まるから**であって、pkill 自体は効いている。

### macOS では unix domain を使わない

**macOS の WezTerm はローカル端末として動かす**（`unix_domains` も
`default_gui_startup_args = {'connect','unix'}` も設定しない）。以前は他の OS と
同じく mux に乗せていたが、実測で次の 4 つが起きたためやめた:

1. **✗ でウィンドウを 1 枚閉じると、その mux の全ウィンドウが消える。** WezTerm は
   クライアント domain のウィンドウを閉じるとき、リモートのセッションを殺さない
   ように **domain ごと detach** する。GUI ログに
   `detaching domain` → `domain detached panes: [18 個…]` が残る。
   この detach だけを止める設定は無い。
2. `--domain-name unix` の自己接続でペインが増殖する（上節）
3. 実体のないゴーストが `cli list` に残り、`kill-pane` でも消せない
4. GUI を閉じても mux が生き残るので、上記のゴミが日をまたいで蓄積する

unix domain を入れた元々の狙いは「tmux ペインから `wezterm cli` を刺しても、GUI を
再起動したソケット変更で壊れないようにする」ことだが、**macOS では tmux を使って
いない**（自動起動は Linux/WSL のみ）ので当てはまらない。tmux を使う Linux
ネイティブでは従来どおり unix domain を張る。

引き換えに、**macOS では GUI を閉じるとその中のシェルも終了する**（セッションは
残らない）。ssh ウィンドウも GUI と一緒に消えるので、mux に residual が積もる問題は
構造的に起きない。

`wezterm cli list` が引けないときは「判断できない」＝ **開いてよい**側に倒す。
ガードのせいで ssh が開けなくなる方が困るため。

> ⚠️ キー待ちのタイムアウトには **bash を明示して使う**こと。Ubuntu の `/bin/sh` は
> dash で `read -t` を持たず、macOS の `/bin/sh` は bash 3.2 で `read -t` の
> タイムアウト時の戻り値が **1**（bash 4 以降の `>128` ではない）。つまり戻り値からは
> 「`-t` 非対応」と「時間切れ」を区別できない。spawn するシェルを `/bin/bash` に
> 選べば分岐そのものが不要になる（bash が無い環境では従来どおり無期限に待つ）。

別ウィンドウが開かずその場で実行されてしまうときは、`SSH_WINDOW_DEBUG=1` を付けると
`wezterm cli` に渡している引数と、握りつぶしているエラーがそのまま出る。

```bash
SSH_WINDOW_DEBUG=1 ssh host
```

### 自己診断

新しい端末でこの仕掛けが本当に動くかは
[ssh-window-selftest](dot_local/bin/executable_ssh-window-selftest) で確認できる。
判定ロジック・環境の解決結果を出したうえで、実際に 1 回ウィンドウを開いて
エラーが読めることまで確かめ、開いたウィンドウは自分で閉じる。

```bash
ssh-window-selftest
```

判定ロジックと環境だけ見たいときは `ssh-window-selftest --dry`。
**とくに macOS で最初に使うときはこれを流すこと**（実装は Windows / WSL2 でのみ
実機確認しており、macOS 側は未検証のため）。

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

tmux
-----

**Linux の対話シェルを開くと自動で tmux に入る。** WSL をローカルで開いた場合も対象。
セッションの永続化（ウィンドウを閉じても作業が残り、次に開いたとき同じ状態に戻る）と、
tmux 側でのウィンドウ / ペイン管理が目的。

実体は [dot_config/zshrc](dot_config/zshrc) の `AGENT_MODE` ガード直下にある数行。
**既存セッションが 1 つでもあればそこへ attach し、1 つも無いときだけ `main` を新規作成
する。** 名前で決め打ちせず `tmux list-sessions` から選ぶので、素の `tmux` で出来た `0` の
ようなセッションが残っている端末でも、別途 `main` を作らずそこへ戻る。複数あるときは
**未 attach のものを優先 → その中で最終利用が新しいもの**の順で選ぶため、端末を 2 つ開けば
別々のセッションに散る。全部 attach 済みのときだけ最後に使ったものへ相乗りする（画面が
同期する）。tmux を抜けるとシェルも終了してウィンドウが閉じる。

macOS ローカルは対象外。WezTerm 自身の mux とタブで完結しており、上記の
「1 OS ウィンドウ = 1 リモートホスト」の手前で tmux を挟むとリモート側と
nested tmux になるため。

設定は [dot_config/tmux/tmux.conf](dot_config/tmux/tmux.conf) → `~/.config/tmux/tmux.conf`。
prefix は `C-b` ではなく **`C-j`**、マウス操作 on、履歴 50000 行。分割は `prefix |`
（横）/ `prefix -`（縦）で、ペイン移動は `prefix h/j/k/l`。`prefix r` で再読み込み。

### ウィンドウ名（タブ名）

`automatic-rename-format` で次のように出る。

| pane の状態 | 表示 | 例 |
| ---- | ---- | ---- |
| シェルで待機中 | カレントディレクトリ名 | `dotfiles` |
| 同上・名前が長い | 12 文字目以降を `...` に | `very-long-d...` |
| フォアグラウンドでプロセス実行中 | そのプロセス名 | `vim` / `less` / `ssh` |

シェル判定は `#{m/r:^(zsh\|bash\|sh\|fish\|dash\|ksh)$,...}` の正規表現で完全一致
させている。fnmatch の `*sh` だと **`ssh` までシェル扱いになってしまう**ため。

> 切り詰めの `#{=/11/...}` が数えるのは文字数ではなく**表示幅**。全角の
> ディレクトリ名は 11 桁 ≒ 5 文字で切れる（`日本語のとても長い名前` →
> `日本語のと...`）。タブ幅が揃うので、この挙動のまま使っている。

### カレントウィンドウの表示

既定の `#I:#W#F` の `#F` には `*`（カレント）や `-`（直前）が混ざる。これをやめて
**背景色の反転**でカレントを示す（`window-status-current-style` に `bg=black,fg=green`）。
前後の空白は、背景の帯を文字の左右まで伸ばして「タブらしく」見せるため。

ズームだけは色で表せないので `Z` を明示的に残してある（`prefix z` で 1 ペイン全画面）。
`-`（直前のウィンドウ）の表示は色では区別できないので無くなる。

### 自動起動しない経路

| 条件 | 理由 |
| ---- | ---- |
| `AGENT_MODE=1` | AI エージェント用シェル。上のブロックで `return` 済み |
| `CLAUDECODE` が設定済み | Claude Code が起こすシェル。tmux を挟むと出力の取り回しが壊れる |
| `TERM_PROGRAM=vscode` | VSCode 統合ターミナルは自前でタブを持ち、シェル統合も壊れる |
| `TERM=dumb` | エディタ内シェルや tramp など端末機能のない経路 |
| `$TMUX` が設定済み | 既に tmux の中（nested 防止） |
| macOS | 上記のとおり対象外 |

一時的に切りたいときは `ZSH_NO_TMUX=1 zsh`。

> tmux が `~/.config/tmux/tmux.conf` を読むのは **3.1 以降**。それより古い tmux の
> ホストでは既定設定のままになる。prefix が `C-b` のままなら `tmux -V` を疑う。

> WezTerm には tmux は無い。WezTerm が持つのは自前の mux で tmux とは別実装なので、
> tmux は接続先（WSL / リモート）に 1 つあるだけ。ウィンドウを閉じるときの確認
> ダイアログも tmux ではなく WezTerm のもの（`window_close_confirmation` の既定値）。

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

独自コマンド（`~/.local/bin`）
-----------------------------
このリポジトリが配る自作コマンドは全部 [dot_local/bin/](dot_local/bin/) に置き、
`chezmoi apply` で `~/.local/bin`（Windows なら `%USERPROFILE%\.local\bin`）へ展開する。
**ここに置けば全 OS で名前だけで呼べる**のが基盤の目的で、新しいコマンドを足すときに
PATH をいじる必要はない。

| OS                | PATH を通しているもの                                                      |
| ----------------- | -------------------------------------------------------------------------- |
| WSL / Linux / mac | [dot_config/zshrc](dot_config/zshrc) 冒頭の `export PATH="$HOME/.local/bin:$PATH"` |
| Windows           | [dot_config/powershell/profile.ps1](dot_config/powershell/profile.ps1)（`setup.ps1` が読ませる） |

Unix 側は `AGENT_MODE` ガードより**上**にあり、エージェント用シェルからも見える。

### Windows で PowerShell プロファイルを噛ませる仕組み

PowerShell が実際に読むのは `$PROFILE.CurrentUserAllHosts` だが、これは Documents 配下
＝**ローカライズされ、しばしば OneDrive に移設される**パス（この端末では
`%USERPROFILE%\OneDrive\ドキュメント\WindowsPowerShell\profile.ps1`）。chezmoi は
1 ソース → 1 固定宛先なので、この値を apply 時に解決できない。そこで:

1. chezmoi が実体を `~/.config/powershell/profile.ps1` に置く（＝リポジトリ管理下）
2. `setup.ps1` の `Install-PowerShellProfile` が、実プロファイルへ
   `. "$env:USERPROFILE\.config\powershell\profile.ps1"` の 1 行を**追記**する

シンボリックリンクではなく追記にしてあるのは、開発者モード／管理者権限が要らず
OneDrive の同期とも相性が良いため。既に該当行があれば何もしない（冪等）。実プロファイルに
端末固有の行が入っていても上書きせず残す。`pwsh`（PowerShell 7）が入っていれば
そちらの `PowerShell\profile.ps1` にも同じ行を入れる。

> 反映には**新しいシェルを開く**必要がある。今のセッションに効かせるなら
> `. $PROFILE.CurrentUserAllHosts`。

### 実行ポリシー（Restricted のままだとプロファイルが読めない）

PowerShell 起動時にこう出るなら、シムの問題ではなく**実行ポリシー**:

```
このシステムではスクリプトの実行が無効になっているため、ファイル
C:\Users\<user>\OneDrive\ドキュメント\WindowsPowerShell\profile.ps1 を読み込むことができません。
```

クライアント版 Windows の Windows PowerShell 5.1 は既定が `Restricted` で、`.ps1` が
一切走らない。プロファイルも `.ps1` なので、シムの追記が正しくても毎回このエラーになり、
`~/.local/bin` が PATH に入らず、このリポジトリが配る `.ps1` コマンドも動かない。
インストール手順の `-Scope Process` の Bypass は `setup.ps1` 自身を走らせるためだけの
一時設定なので、これだけでは次のシェルで元に戻る。

恒久対応は `setup.ps1` の `Set-UserExecutionPolicy` が行う（`Install-PowerShellProfile`
の直前に実行）。単体で直すならこれ 1 行で、**管理者権限は不要**:

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

* スコープを `CurrentUser` にしているのは、昇格が要らず `LocalMachine` を汚さないため
  （優先順位は `MachinePolicy` > `UserPolicy` > `Process` > `CurrentUser` > `LocalMachine`
  なので、`LocalMachine` が Restricted でも `CurrentUser` が勝つ）。
* `RemoteSigned` は「ローカルで作った `.ps1` は無署名で実行可、ダウンロード由来
  （mark-of-the-web 付き）は署名必須」。chezmoi が書くファイルには MOTW が付かないので
  これで足りる。`Unrestricted` / `Bypass` まで緩める必要はない。
* 設定先は HKCU なので、`setup.ps1` を昇格して走らせる場合も**同じアカウント**であること。
  「別のユーザーとして実行」だとそちらのアカウントに入ってしまう。
* `MachinePolicy` / `UserPolicy` が `Undefined` 以外（＝グループポリシー管理下）のときは
  ローカルで何を設定しても効かない。`setup.ps1` はその場合、黙って成功したように
  見せずに警告を出してスキップする。現状を見るなら `Get-ExecutionPolicy -List`。

### `chezmoi-merge`

`claude` を起動して [chezmoi-merge スキル](dot_claude/skills/chezmoi-merge/SKILL.md)
（pull → 突合 → apply → push）を走らせるだけのラッパ。どの OS でも同じ名前で叩ける。

```bash
chezmoi-merge              # 対話セッションを開いて /chezmoi-merge を投げる
chezmoi-merge "tmux だけ"  # 初回プロンプトに補足を足す
```

* 実体は 2 本。[dot_local/bin/executable_chezmoi-merge](dot_local/bin/executable_chezmoi-merge)（bash）と
  [dot_local/bin/chezmoi-merge.ps1](dot_local/bin/chezmoi-merge.ps1)（PowerShell）。
  やることは同じで、`chezmoi source-path` へ移動してから `claude "/chezmoi-merge"` を exec する。
  cwd を source-path にするのはスキルがそこ基準で動くのと、リポジトリの `CLAUDE.md` を
  読ませるため。
* **Windows でも `.ps1` を打つ必要はない。** `.PS1` は `PATHEXT` に無いが、PowerShell の
  コマンド解決は PATH 上の `.ps1` を拡張子なしで拾う（cmd.exe は拾わないので、そちらでは
  `chezmoi-merge.ps1` とフルネームで打つ）。ファイル名から拡張子自体は落とせない
  （shebang が無く、解決が拡張子ベースのため）。
* **対話セッションで起動する。** スキルが項目ごとにユーザーの判断を仰ぐ設計なので、
  `-p` / `--print` を足さないこと。
* `chezmoi` か `claude` が見つからなければ 127 で止まり、導入方法を出す。
  Windows で `claude` が無いとき **WSL の `claude` にはフォールバックしない**：
  WSL 側の chezmoi は `/home/<user>` を管理するので、Windows のプロファイルではなく
  WSL の dotfiles を同期してしまい、意図と逆になる。

### `lmstudio-to-ollama`

LM Studio がダウンロード済みの GGUF を Ollama 側にも登録する。

```bash
lmstudio-to-ollama                 # LM Studio の一覧と、付く ollama 名を表示
lmstudio-to-ollama qwen3.6-27b     # パスの部分一致で 1 つ選んで取り込む
lmstudio-to-ollama gpt-oss -n gpt-oss:20b
```

**なぜラッパが要るか。** Ollama は `.gguf` の入ったディレクトリを読めない。モデル置き場は
content-addressed（`manifests` + `sha256-<digest>` という名の blob）で、LM Studio の
`~/.lmstudio/models/<publisher>/<repo>/*.gguf` を `OLLAMA_MODELS` に指しても認識しない。
唯一の入り口は Modelfile の `FROM` に `.gguf` を書いて `ollama create` する経路だが、
**これはファイルをコピーする** — 20GB のモデルなら 20GB を二重に持つことになる。

そこでこのコマンドは 2 段階でやる:

1. `ollama create` で取り込む（ここで一度コピーされる）
2. できた blob を LM Studio 側のファイルへの**ハードリンクに差し替える**

同一ファイルシステム・同一実体になるので、ディスク消費は 1 つぶん。ハードリンクは
「同じ実体に付いた 2 つ目の名前」なので、あとで `ollama rm` しても LM Studio のモデルは
道連れにならず、逆に LM Studio 側を消しても Ollama から使い続けられる。

* 実体は 2 本。[dot_local/bin/executable_lmstudio-to-ollama](dot_local/bin/executable_lmstudio-to-ollama)（bash）と
  [dot_local/bin/lmstudio-to-ollama.ps1](dot_local/bin/lmstudio-to-ollama.ps1)（PowerShell）。
* LM Studio のモデル置き場は移動できるので、`settings.json` の `downloadsFolder` を読む。
  `LMSTUDIO_MODELS_DIR` / `OLLAMA_MODELS` で上書きできる。
* **`mmproj-*.gguf`（vision projector）は非対応。** Modelfile から紐づける手段が無く、
  取り込んでもテキスト専用になるため一覧から外してある。
* ハードリンク化は best-effort。別ボリューム・サイズ不一致・`ln` 失敗などで少しでも
  怪しければ**コピーのまま残す**（それでも動く）。最初からコピーで欲しいときは `--copy` / `-Copy`。
* Windows で実測（Bonsai-27B-Q1_0 / 3.54GB）: `create` に 29.8 秒＋コピー 3.55GB、
  差し替え後は `fsutil file queryfileid` が LM Studio 側と同一 File ID を返し、
  サーバ再起動後の推論も通った。チャットテンプレートは GGUF メタデータから引き継がれる。
  bash 版は WSL 上でスタブを使った動作確認まで（実モデルでの検証は Windows 版のみ）。

> ⚠️ 空き容量の増減で二重取りの有無を判断しないこと。稼働中の Windows では他要因の
> 増減に埋もれる。確認は `fsutil hardlink list <blob>`（Windows）／`stat -c %i`（Unix）で
> **同一 inode / File ID か**を見る。

### `ollama-to-opencode`

ローカルの Ollama モデルを [opencode](https://opencode.ai/) から使えるようにする。

```bash
ollama-to-opencode                    # ローカルのモデルと現在の登録状況
ollama-to-opencode gpt-oss-20b-mxfp4  # プローブ → 焼き込み → 登録 → 疎通確認
ollama-to-opencode a b --default a
```

モデルごとに 4 つのことをする:

1. **100% GPU に載る最大コンテキストを実測**する（学習長から半分ずつ下げて試す。
   `--ctx` / `-Ctx` で指定すれば省略）
2. それを `<model>:<tag>`（例 `gpt-oss-20b-mxfp4:128k`）に `ollama create` で
   **焼き込む**。blob を共有するのでディスクは増えない
3. `~/.config/opencode/opencode.json(c)` の `provider.ollama` に登録し、
   `baseURL` を `http://localhost:11434/v1` に向ける
4. その `/v1` 経由で 1 回投げて**疎通確認**する

> **なぜコンテキストをモデルに焼き込むのか。** opencode は OpenAI 互換
> エンドポイント経由で Ollama を叩くが、この API には `num_ctx` を渡す場所が無い。
> 指定が無いと Ollama は VRAM から既定値を決め（16GB カードで 4096）、opencode の
> システムプロンプトだけで約 9.4k トークンあるため**切り捨てられる**。エージェントの
> 挙動が壊れるうえ、プロンプトキャッシュが毎ターン無効化されて再プリフィルが走る。
> `OLLAMA_CONTEXT_LENGTH` を全体に設定するのは誤った手で、その値を VRAM に収められない
> 大きいモデルまで CPU へ追い出してしまう（実測で `qwen3.6-27b` が該当）。

* 設定ファイルは**マージ**する。既存の他プロバイダやキーは残し、書き込み前に
  `.bak` へ退避する（コメントは保持されない）。JSONC のコメントと末尾カンマは
  文字列を認識しながら除去するので、`"https://example.com//x"` のような値も壊れない。
* 実測例（RX 9070 XT / VRAM 15.9GB）: `gemma-4-12b-it-q4_k_m` は 262144 で 8.3GB・100% GPU、
  `gpt-oss-20b-mxfp4` は自身の上限 131072 で 11GB・100% GPU、`qwen3.6-27b-q4_k_m` は
  16384 でも CPU へこぼれる。コンテキストを 8k→256k に変えても生成速度は変わらなかった。

### `lmstudio-to-opencode`

LM Studio のモデルを opencode で使える状態まで一気に持っていくオーケストレータ。
中身は上の 2 つを順に呼ぶだけで、どちらも単体で使える。

```bash
lmstudio-to-opencode qwen3.6-27b   # 取り込み → 設定 → 疎通確認
lmstudio-to-opencode --all         # LM Studio の全モデル
```

* `--ctx` / `--no-verify` / `--force` は下位コマンドへそのまま渡す。オプションを
  二重管理しないため、自分で解釈するのは `--all` / `--default` / `--list` だけ。
* 内部では `lmstudio-to-ollama --print-ref`（標準出力にモデル ref だけを返し、
  取り込み済みならエラーにせず ref を返す）と `--list-paths` を使う。

### opencode の設定ファイル（Windows のみ）

生成された設定 [dot_config/opencode/opencode.jsonc](dot_config/opencode/opencode.jsonc) も
chezmoi 管理下に置いてある。ただし**配るのは Windows だけ**で、[.chezmoiignore](.chezmoiignore)
の windows ガードに `.config/opencode/` を入れてある。登録しているモデル名も焼き込んだ
コンテキストも、この機体の GPU（RX 9070 XT / VRAM 15.9GB）で実測して決めた値なので、
別マシンにそのまま配っても意味がないため。

`ollama-to-opencode` はこのファイルを書き換えるので、実行後は
`chezmoi add ~/.config/opencode/opencode.jsonc` でリポジトリへ戻すこと。

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

### VSCode の Settings Sync との分担

**`settings.json` は chezmoi が持ち、拡張機能と UI State は VSCode の Settings Sync に
任せる**、という分担にしている。

| 対象                                    | 持ち主          |
| --------------------------------------- | --------------- |
| `settings.json`                         | **chezmoi**     |
| 拡張機能                                | Settings Sync   |
| UI State（最近開いた項目・レイアウト等）| Settings Sync   |
| keybindings / snippets / tasks          | 実体が無いので現状どちらでもない |

理由は、**Settings Sync が `settings.json` を OS をまたいでそのまま運んでしまう**から。
端末ごとに違う値（docker の絶対パス、社用証明書のパス）まで配られてしまい、実際に
macOS の `/opt/homebrew/bin/docker` や `/Users/<user>/.config/certs/...` が Windows 側の
`settings.json` に流れ込んでいた。この出し分けは chezmoi のテンプレートが
`lookPath` / `stat` でやっている仕事なので、そちらに寄せる。

逆に**拡張機能はどの端末でも同じ**で、端末差を吸収する必要がない。Settings Sync の
自動インストールの方が手間が少ないので、そのまま任せている。

#### 切り替え手順（端末ごとに 1 回）

1. **先に差分を確認する。** その端末の `settings.json` にしか無い設定があると、
   chezmoi に寄せた時点で失われる。残したいものがあれば
   [.chezmoitemplates/vscode-settings.json](.chezmoitemplates/vscode-settings.json) へ手で移す。

   ```bash
   chezmoi diff ~/Library/Application\ Support/Code/User/settings.json   # macOS
   ```

   VSCode はキーの順序を勝手に変えるので diff は素直に読めない。**キー名の増減**だけ見ればよい。

2. コマンドパレット（`Ctrl+Shift+P` / `Cmd+Shift+P`）→ **`Settings Sync: Configure...`**
   → **`Settings` のチェックだけ外す**。他（Extensions / UI State など）は残す。

3. chezmoi 版で上書きし直す。

   ```bash
   chezmoi apply --force ~/Library/Application\ Support/Code/User/settings.json
   ```

#### 保険

万が一 Settings Sync の `Settings` が再び有効になっても事故が再発しないよう、
テンプレート冒頭で `settingsSync.ignoredSettings` に**端末ごとに値が変わるキー**を
列挙している。テンプレートが `lookPath` / `stat` で出し分けているキーと同じ顔ぶれ。

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
