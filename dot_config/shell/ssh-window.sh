# ~/.config/shell/ssh-window.sh — 対話ログイン目的の ssh を WezTerm の別ウィンドウで開く
#
#   目的: ローカルの tmux はそのまま使いつつ、ssh 先では nested tmux にしない。
#         「1 OS ウィンドウ = 1 リモートホスト」を保つ。
#   相方: ~/.wezterm.lua (chezmoi ソース: dot_wezterm.lua)
#   対象: macOS (zsh) / WSL2 (zsh) 共通。判定ロジックは 1 本、OS 差分は
#         spawn コマンドの組み立てだけに閉じ込めてある。
#
# 無効化したいとき:
#   SSH_NO_NEW_WINDOW=1 ssh host   # 1 回だけその場で実行
#   export SSH_NO_NEW_WINDOW=1     # そのシェルでは常にその場で実行
#   unset -f ssh                   # ラッパー自体を外す
#
# 端末ごとの調整:
#   SSH_WINDOW_DOMAIN       spawn 先の WezTerm domain 名を上書き
#   SSH_WINDOW_RUNTIME_DIR  WezTerm のランタイムディレクトリを上書き (下の解説を参照)
#   SSH_WINDOW_DEBUG=1      wezterm cli のコマンドラインとエラーを表示する
#                           （別ウィンドウが開かず、その場実行に落ちるときの原因調査用）
#
# 捕まえないもの (仕様):
#   - git / rsync / scp / ansible が内部で呼ぶ ssh
#     → シェル関数は対話的にコマンドラインを解釈するときにしか効かず、
#       execve で直接呼ばれる ssh には届かない。これは副作用ではなく設計。
#   - ssh host <command> のようなリモートコマンド実行、-N/-W/-f 等の非対話用途
#     → §should_spawn の判定で弾く。
#
# NOTE: 部分文字列展開 ${var:0:1} を使うので bash / zsh 専用（sh では動かない）。

# ---------------------------------------------------------------------------
# rc 読み込み時に 1 度だけ評価する
# （対話シェルの応答性に効くので、ssh を叩くたびに uname を呼んだりしない）
# ---------------------------------------------------------------------------
__ssh_window_platform=''   # macos | wsl | linux | ''(非対応)
__ssh_window_wezterm=''    # 実行する wezterm バイナリ
__ssh_window_domain=''     # spawn 先の WezTerm domain 名

__ssh_window_init() {
  case "$(uname -s)" in
    Darwin)
      __ssh_window_platform='macos'
      if command -v wezterm >/dev/null 2>&1; then
        __ssh_window_wezterm='wezterm'
      elif [ -x '/Applications/WezTerm.app/Contents/MacOS/wezterm' ]; then
        # GUI から起動した WezTerm と、ターミナルから起動したものとで PATH が
        # 違うことがあるので、アプリ内の実体にフォールバックする。
        __ssh_window_wezterm='/Applications/WezTerm.app/Contents/MacOS/wezterm'
      fi
      # .wezterm.lua の unix_domains の名前と合わせること。
      __ssh_window_domain='unix'
      ;;
    Linux)
      if grep -qi microsoft /proc/version 2>/dev/null; then
        # WSL2: シェルは Linux 側、WezTerm GUI は Windows 側。境界を越える。
        __ssh_window_platform='wsl'
        if command -v wezterm.exe >/dev/null 2>&1; then
          __ssh_window_wezterm='wezterm.exe'
        elif [ -x '/mnt/c/Program Files/WezTerm/wezterm.exe' ]; then
          # PATH interop が切られている環境向けのフォールバック。
          __ssh_window_wezterm='/mnt/c/Program Files/WezTerm/wezterm.exe'
        fi
        # WSL domain を指定しないと Windows 側の ssh.exe が起動してしまい、
        # WSL の ~/.ssh/config も鍵も参照されない。
        __ssh_window_domain="WSL:${WSL_DISTRO_NAME:-Ubuntu}"
      else
        __ssh_window_platform='linux'
        command -v wezterm >/dev/null 2>&1 && __ssh_window_wezterm='wezterm'
        __ssh_window_domain='unix'
      fi
      ;;
  esac
  # 端末ごとの上書き用。domain 名が違う環境ではこれを export すればよい。
  [ -n "$SSH_WINDOW_DOMAIN" ] && __ssh_window_domain="$SSH_WINDOW_DOMAIN"
}
__ssh_window_init
unset -f __ssh_window_init

# ---------------------------------------------------------------------------
# 引数を解析して「対話ログイン目的の ssh か」を判定する
#   戻り値 0 = 別ウィンドウで開いてよい / 1 = その場で実行する
#   副作用 __ssh_window_dest に destination (user@host 等) を入れる
#
# 迷ったら必ず 1（その場実行）に倒す。ラッパーが壊れても ssh が使えなくなっては
# ならないため。
# ---------------------------------------------------------------------------
__ssh_window_parse() {
  # 次の引数を値として食うオプション
  local optval='BbcDEeFIiJLlmOopQRSWw'
  # 値を取らないフラグ
  local noval='46AaCfGgKkMNnqsTtVvXxYy'
  # これが現れたら非対話用途とみなして弾く
  #   N ポートフォワード専用 / W stdio フォワード / O ControlMaster 制御
  #   f バックグラウンド / T pty なし / G 設定ダンプ / Q クエリ
  #   V バージョン / s サブシステム (sftp 等)
  local excl='NWOfTGQVs'

  local a rest ch
  __ssh_window_dest=''

  while [ "$#" -gt 0 ]; do
    a="$1"
    shift
    case "$a" in
      --)
        # ssh は getopt(3) を使うので -- でオプション終端になる
        [ "$#" -eq 0 ] && return 1
        __ssh_window_dest="$1"
        shift
        [ "$#" -gt 0 ] && return 1   # destination の後ろ = リモートコマンド
        return 0
        ;;
      -*)
        # -tv のような連結形も 1 文字ずつ見る
        rest="${a#-}"
        while [ -n "$rest" ]; do
          ch="${rest:0:1}"
          rest="${rest:1}"
          case "$excl" in *"$ch"*) return 1 ;; esac
          case "$noval" in *"$ch"*) continue ;; esac
          case "$optval" in
            *"$ch"*)
              if [ -n "$rest" ]; then
                rest=''              # -p2222 形式: 同じ引数の残りが値
              else
                [ "$#" -eq 0 ] && return 1   # 値が無い = 不正な呼び出し
                shift                # -p 2222 形式: 次の引数が値
              fi
              ;;
            *) return 1 ;;           # 知らないオプション → 安全側に倒す
          esac
        done
        ;;
      *)
        __ssh_window_dest="$a"
        [ "$#" -gt 0 ] && return 1   # destination の後ろ = リモートコマンド
        return 0
        ;;
    esac
  done

  return 1                           # destination が無い (ssh 単体実行など)
}

# ---------------------------------------------------------------------------
# WezTerm のランタイムディレクトリ（gui ソケットの置き場）を解決する
# ---------------------------------------------------------------------------
# WezTerm 20240203 の Windows 版は gui ソケットを相対パスで開きにいくため、
# ランタイムディレクトリを cwd にしていないと `wezterm cli` が接続できない:
#   ERROR wezterm > failed to connect to Socket("gui-sock-<pid>"); terminating
# （2 秒ほどリトライしてから死ぬので、ラッパーからだと単に spawn 失敗に見える）
#
# WSL からだと Windows 側の %USERPROFILE% 配下を指す必要があり、Windows の
# ユーザー名は WSL のそれと一致しないので実際に引く。cmd.exe を起動するぶん
# 遅いので、シェル起動時ではなく初回 spawn 時に遅延評価してキャッシュする。
# 自動解決に失敗する端末では SSH_WINDOW_RUNTIME_DIR で上書きできる。
__ssh_window_runtime=''

__ssh_window_resolve_runtime() {
  [ -n "$__ssh_window_runtime" ] && return 0

  if [ -n "$SSH_WINDOW_RUNTIME_DIR" ]; then
    __ssh_window_runtime="$SSH_WINDOW_RUNTIME_DIR"
    return 0
  fi

  local win_home dir='' cmd_exe=''
  if [ "$__ssh_window_platform" = 'wsl' ]; then
    # PATH interop が切られている環境向けに、wezterm.exe と同様フルパスも見る。
    if command -v cmd.exe >/dev/null 2>&1; then
      cmd_exe='cmd.exe'
    elif [ -x '/mnt/c/Windows/System32/cmd.exe' ]; then
      cmd_exe='/mnt/c/Windows/System32/cmd.exe'
    fi
    # cwd が /mnt/c 配下でないと cmd.exe が UNC 警告を出すので移動してから叩く。
    # コマンド置換は subshell なので cd は呼び出し元に漏れない。
    # zshrc の cd は ls を吐くため必ず builtin を使う。ここを素の cd にすると
    # ディレクトリ一覧が win_home に混入してパスが壊れる。
    if [ -n "$cmd_exe" ]; then
      win_home="$(builtin cd /mnt/c 2>/dev/null; "$cmd_exe" /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r\n')"
      [ -n "$win_home" ] && dir="$(wslpath -u "$win_home" 2>/dev/null)/.local/share/wezterm"
    fi
  else
    # macOS には XDG_RUNTIME_DIR が無いので既定は ~/.local/share/wezterm。
    dir="${XDG_RUNTIME_DIR:-$HOME/.local/share}/wezterm"
  fi

  # 実在するディレクトリのときだけ採用する。解決に失敗したら空のままにして
  # cd をスキップさせ、最終的にその場実行へフォールバックさせる。
  [ -n "$dir" ] && [ -d "$dir" ] && __ssh_window_runtime="$dir"
  [ -n "$__ssh_window_runtime" ]
}

# wezterm cli を「接続できる状態」で叩く薄いラッパー。
# subshell 内で完結させ、cwd と環境変数の細工を呼び出し元に漏らさない。
__ssh_window_cli() {
  (
    # zshrc の cd は ls を吐く。stdout が汚れると pane id が壊れるので builtin 固定。
    if [ -d "$__ssh_window_runtime" ]; then
      builtin cd "$__ssh_window_runtime" || return 1
    fi

    if [ "$__ssh_window_platform" != 'wsl' ]; then
      # tmux の環境変数は tmux サーバ起動時のもので固定される。WezTerm を再起動
      # したあと古いペインから呼ぶと死んだソケットを掴むので、tmux のセッション
      # 環境から引き直す (tmux.conf の update-environment に登録済み)。
      # WSL 経路では WEZTERM_UNIX_SOCKET は Windows 側の値なので意味を持たない。
      if [ -n "$TMUX" ]; then
        eval "$(command tmux show-environment -s WEZTERM_UNIX_SOCKET 2>/dev/null)"
      fi
    fi
    # 死んだペインを指している可能性があるので落とす。domain は呼び出し側で
    # 明示するので、WEZTERM_PANE から現在の domain を推測させる必要はない。
    unset WEZTERM_PANE

    # 平常時は wezterm cli のエラーを握りつぶす。GUI を起動していない端末で
    # ssh を叩くたびに警告が出ると邪魔なため。原因を追いたいときは
    # SSH_WINDOW_DEBUG=1 を付けると素通しになる。
    if [ -n "${SSH_WINDOW_DEBUG:-}" ]; then
      printf 'ssh-window: %s %s (cwd=%s)\n' "$__ssh_window_wezterm" "$*" "$PWD" >&2
      "$__ssh_window_wezterm" "$@"
    else
      "$__ssh_window_wezterm" "$@" 2>/dev/null
    fi
  )
}

# ---------------------------------------------------------------------------
# ラッパー本体
# ---------------------------------------------------------------------------
ssh() {
  # --- 前提条件 (§5.1) ---
  if [ -z "$__ssh_window_wezterm" ] ||
     [ -n "$SSH_NO_NEW_WINDOW" ] ||
     [ -n "$WEZTERM_SSH_WINDOW" ] ||
     [ ! -t 0 ] || [ ! -t 1 ]; then
    command ssh "$@"
    return
  fi

  # local は動的スコープなので、__ssh_window_parse から書いた値もここで受け取れる。
  # グローバルを汚さないためにこの形にしている。
  local __ssh_window_dest pane_id
  if ! __ssh_window_parse "$@"; then
    command ssh "$@"
    return
  fi

  __ssh_window_resolve_runtime

  # ssh 自身がエラーで落ちたときだけキー入力を待ってウィンドウを残す。
  # WezTerm の exit_behavior='CloseOnCleanExit' でも似たことはできるが、あれは
  # 全ペインに効くので「失敗したコマンドの直後に exit した通常のシェル」まで
  # 残ってしまう。ここで面倒を見ればグローバル設定は既定の 'Close' のままでよい。
  #
  # 判定に 255 を使うのは ssh(1) の仕様による: ssh はリモートコマンドの終了
  # ステータスをそのまま返し、ssh 自身のエラー（名前解決失敗・接続拒否・認証
  # 失敗など）のときだけ 255 を返す。おかげで「リモートで最後のコマンドが
  # 失敗したまま exit した」ケースでは、ここで引っかからず素直に閉じる。
  #
  # シングルクォートを含めないこと: この文字列は zsh → wezterm.exe(Windows) →
  # wsl.exe → sh と 2 回境界を越える。空白と二重引用符が保たれることは検証済み。
  local hold='ssh "$@"; __st=$?; if [ "$__st" -eq 255 ]; then echo; echo "[ssh がエラーで終了しました (255)。Enter でこのウィンドウを閉じます]"; read -r __dummy; fi; exit "$__st"'

  # env で立てているループガードは、spawn 先のシェル経由でこのラッパーが
  # 再入しないための保険（sh は rc を読まないので実際には発火しない）。
  pane_id="$(__ssh_window_cli cli spawn --new-window \
    --domain-name "$__ssh_window_domain" \
    -- env WEZTERM_SSH_WINDOW=1 /bin/sh -c "$hold" ssh-window "$@")"

  # spawn は pane id (数値) を stdout に吐く。Windows バイナリ由来の CR や
  # 想定外の出力が混ざっても壊れないよう、先頭の数字だけを取り出す。
  pane_id="${pane_id%%[!0-9]*}"

  # spawn できなかった (mux が落ちている / domain 名が違う 等) ならその場で実行。
  # ここで詰まらせないことが最優先。
  if [ -z "$pane_id" ]; then
    command ssh "$@"
    return
  fi

  # タイトル設定は失敗しても致命的でないので握りつぶす。
  __ssh_window_cli cli set-tab-title --pane-id "$pane_id" \
    "ssh: $__ssh_window_dest" >/dev/null 2>&1

  printf 'ssh: %s → WezTerm の新しいウィンドウで接続中\n' "$__ssh_window_dest" >&2
  return 0
}
