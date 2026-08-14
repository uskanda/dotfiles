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
#   SSH_WINDOW_COOLDOWN     同じ宛先を続けて開くのを抑止する秒数 (既定 5、0 で無効)
#   SSH_WINDOW_MAX          同時に開いておける ssh ウィンドウ数 (既定 8、0 で無制限)
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
__ssh_window_state=''      # 開いた ssh ウィンドウの台帳 (暴走ガード用)

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

  # 台帳は同一ホストの同一ユーザーでのみ共有する。/tmp を使う環境もあるので
  # ファイル名に uid を入れて他ユーザーのものを掴まないようにする。
  __ssh_window_state="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}"
  __ssh_window_state="${__ssh_window_state%/}/ssh-window-${UID:-$(id -u)}.panes"

  # 経過秒の取得に使う。bash 5 / zsh (zsh/datetime) なら外部コマンドを呼ばずに済む。
  [ -n "$ZSH_VERSION" ] && zmodload zsh/datetime 2>/dev/null
}
__ssh_window_init
unset -f __ssh_window_init

__ssh_window_now() {
  if [ -n "${EPOCHSECONDS:-}" ]; then
    printf '%s\n' "${EPOCHSECONDS%%.*}"
  else
    date +%s 2>/dev/null || printf '0\n'
  fi
}

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
# 暴走ガード: 開いた ssh ウィンドウの台帳
# ---------------------------------------------------------------------------
# 「疎通できないホストへ ssh した」ときが一番危ない。ssh 自身は TCP のタイムアウト
# まで（既定で 1 分以上）黙って粘るのに、ラッパーは spawn した時点で 0 を返して
# プロンプトへ戻る。つまり
#   - 開かなかったように見えてユーザーが何度も叩く
#   - `until ssh host; do :; done` のような再試行ループに噛む
# のいずれでもウィンドウだけが際限なく積み上がる。ウィンドウ 1 枚が生きている限り
# 同じ宛先を開き直さない・全体の枚数に上限を設ける、の 2 段で止める。
#
# 台帳は 1 行 = "<pane_id> <開いた時刻(epoch)> <宛先>"。ウィンドウが閉じられても
# 誰も消しに来ないので、参照するたびに `wezterm cli list` と突き合わせて死んだ行を
# 落とす（＝ゴミが残っても次回に自然回復する）。
#
# 副作用:
#   __ssh_window_live_count  生きている ssh ウィンドウの数
#   __ssh_window_live_pane   引数の宛先に対する最新の生存 pane id (無ければ空)
#   __ssh_window_live_ts     その pane を開いた時刻
__ssh_window_scan() {
  local dest="$1" snapshot='' kept='' pane ts d

  __ssh_window_live_count=0
  __ssh_window_live_pane=''
  __ssh_window_live_ts=0

  [ -n "$__ssh_window_state" ] && [ -s "$__ssh_window_state" ] || return 0

  # 台帳が空でないときだけ問い合わせる（wezterm cli は WSL 越しだと遅いため）。
  # 取得に失敗したら全滅とみなす。開きすぎを防ぐガードなので、判断できないときは
  # 「開いてよい」側に倒す方が本来の挙動を壊さない。
  snapshot="$(__ssh_window_cli cli list --format json)" || snapshot=''

  while IFS=' ' read -r pane ts d; do
    [ -n "$pane" ] && [ -n "$d" ] || continue
    case "$pane" in ''|*[!0-9]*) continue ;; esac
    case "$ts" in ''|*[!0-9]*) ts=0 ;; esac
    printf '%s' "$snapshot" |
      grep -Eq "\"pane_id\"[[:space:]]*:[[:space:]]*${pane}([^0-9]|\$)" || continue
    kept="${kept}${pane} ${ts} ${d}
"
    __ssh_window_live_count=$((__ssh_window_live_count + 1))
    if [ "$d" = "$dest" ] && [ "$ts" -ge "$__ssh_window_live_ts" ]; then
      __ssh_window_live_pane="$pane"
      __ssh_window_live_ts="$ts"
    fi
  done < "$__ssh_window_state"

  # 書き戻しは temp + mv で原子的に。複数ペインから同時に ssh しても
  # 半端な行を読ませない。
  if [ -n "$kept" ]; then
    printf '%s' "$kept" > "$__ssh_window_state.$$" 2>/dev/null &&
      mv -f "$__ssh_window_state.$$" "$__ssh_window_state" 2>/dev/null
  else
    rm -f "$__ssh_window_state" 2>/dev/null
  fi
  rm -f "$__ssh_window_state.$$" 2>/dev/null
  return 0
}

__ssh_window_record() {
  [ -n "$__ssh_window_state" ] || return 0
  ( umask 077; printf '%s %s %s\n' "$1" "$2" "$3" >> "$__ssh_window_state" ) 2>/dev/null
  return 0
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
  local __ssh_window_dest pane_id spawn_status=0
  local __ssh_window_live_count __ssh_window_live_pane __ssh_window_live_ts
  local now cooldown max
  if ! __ssh_window_parse "$@"; then
    command ssh "$@"
    return
  fi

  __ssh_window_resolve_runtime

  # --- 暴走ガード (§台帳) -------------------------------------------------
  cooldown="${SSH_WINDOW_COOLDOWN:-5}"
  max="${SSH_WINDOW_MAX:-8}"
  case "$cooldown" in ''|*[!0-9]*) cooldown=5 ;; esac
  case "$max" in ''|*[!0-9]*) max=8 ;; esac

  __ssh_window_scan "$__ssh_window_dest"
  now="$(__ssh_window_now)"

  # 直前に同じ宛先で開いたウィンドウが生きているなら、開き直さずそちらを前に出す。
  # 疎通しないホストは ssh が黙って粘るので、ここが無いと連打のぶんだけ増える。
  if [ -n "$__ssh_window_live_pane" ] && [ "$cooldown" -gt 0 ] &&
     [ "$((now - __ssh_window_live_ts))" -lt "$cooldown" ]; then
    __ssh_window_cli cli activate-pane --pane-id "$__ssh_window_live_pane" >/dev/null 2>&1
    printf 'ssh: %s は開いたばかりのウィンドウがあります (%s 秒以内の再実行を抑止。SSH_WINDOW_COOLDOWN=0 で無効化)\n' \
      "$__ssh_window_dest" "$cooldown" >&2
    return 0
  fi

  # 全体の枚数にも上限を置く。宛先が毎回違う暴走はここで止まる。上限に達したら
  # その場実行に落とす: ssh が前面で走るぶん、次の 1 回が勝手に始まらない。
  if [ "$max" -gt 0 ] && [ "$__ssh_window_live_count" -ge "$max" ]; then
    printf 'ssh-window: ssh ウィンドウが %s 枚開いているため、その場で実行します (SSH_WINDOW_MAX で調整)\n' \
      "$__ssh_window_live_count" >&2
    command ssh "$@"
    return
  fi

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
  # キー待ちには必ずタイムアウトを付けること。unix domain / WSL domain の mux は
  # GUI を閉じても生き残るので、待ち続けるペインは「閉じたつもりのウィンドウ」として
  # mux に溜まり続け、次に GUI が繋いだ瞬間に全部まとめて開き直す（実測: 失敗した
  # ssh ウィンドウが 8 枚 mux に residual していた）。読める時間だけ残して自然に消す。
  #
  # シングルクォートを含めないこと: この文字列は zsh → wezterm.exe(Windows) →
  # wsl.exe → sh と 2 回境界を越える。空白と二重引用符が保たれることは検証済み。
  #
  # タイムアウト付きの待ちには bash を使う。Ubuntu の /bin/sh は dash で read -t を
  # 持たず、macOS の /bin/sh は bash 3.2 で -t の戻り値が 1（bash 4 以降の >128 では
  # ない）ため、「-t 非対応」と「時間切れ」を戻り値では区別できない。シェルの方を
  # 選べば分岐が要らなくなる。bash が無い環境では従来どおり無期限に待つ。
  local hold_sh='/bin/sh' hold_wait='read -r __dummy' hold_note=''
  if [ -x /bin/bash ]; then
    hold_sh='/bin/bash'
    hold_wait='read -t 300 -r __dummy'
    hold_note=' / 5 分で自動的に閉じます'
  fi
  local hold='ssh "$@"; __st=$?; if [ "$__st" -eq 255 ]; then echo; echo "[ssh がエラーで終了しました (255)。Enter でこのウィンドウを閉じます'"$hold_note"']"; '"$hold_wait"'; fi; exit "$__st"'

  # env で立てているループガードは、spawn 先のシェル経由でこのラッパーが
  # 再入しないための保険（sh は rc を読まないので実際には発火しない）。
  pane_id="$(__ssh_window_cli cli spawn --new-window \
    --domain-name "$__ssh_window_domain" \
    -- env WEZTERM_SSH_WINDOW=1 "$hold_sh" -c "$hold" ssh-window "$@")" || spawn_status=$?

  # spawn は pane id (数値) を stdout に吐く。Windows バイナリ由来の CR や
  # 想定外の出力が混ざっても壊れないよう、先頭の数字だけを取り出す。
  pane_id="${pane_id%%[!0-9]*}"

  # domain 指定で失敗したときの保険 (macOS / Linux 限定)。設定が古くて unix
  # domain がまだ無い、といったケースでも既定 domain で開き直せば繋がる。
  # WSL では絶対にやらないこと: domain を外すと Windows 側の ssh.exe が起動して
  # しまい、WSL の ~/.ssh/config も鍵も参照されない。その場実行の方がまだ正しい。
  #
  # 再試行の条件に spawn_status を入れているのは、ウィンドウが 2 枚開くのを
  # 防ぐため。wezterm cli が 0 を返したのに pane id を読めなかった場合、
  # ウィンドウは開いている公算が高いので開き直さない。
  if [ -z "$pane_id" ] && [ "$spawn_status" -ne 0 ] && [ "$__ssh_window_platform" != 'wsl' ]; then
    pane_id="$(__ssh_window_cli cli spawn --new-window \
      -- env WEZTERM_SSH_WINDOW=1 "$hold_sh" -c "$hold" ssh-window "$@")"
    pane_id="${pane_id%%[!0-9]*}"
  fi

  # spawn できなかった (mux が落ちている / domain 名が違う 等) ならその場で実行。
  # ここで詰まらせないことが最優先。
  if [ -z "$pane_id" ]; then
    if [ "$spawn_status" -eq 0 ]; then
      # 開いた可能性が高いので二重に繋がない。台帳にも載らないぶんガードが
      # 効かないので、その旨を出して調べ方を案内する。
      printf 'ssh-window: ウィンドウは開いたはずですが pane id を読めませんでした。開かないときは SSH_WINDOW_DEBUG=1 ssh %s か SSH_NO_NEW_WINDOW=1 ssh %s\n' \
        "$__ssh_window_dest" "$__ssh_window_dest" >&2
      return 0
    fi
    command ssh "$@"
    return
  fi

  __ssh_window_record "$pane_id" "$now" "$__ssh_window_dest"

  # タイトル設定は失敗しても致命的でないので握りつぶす。
  __ssh_window_cli cli set-tab-title --pane-id "$pane_id" \
    "ssh: $__ssh_window_dest" >/dev/null 2>&1

  printf 'ssh: %s → WezTerm の新しいウィンドウで接続中\n' "$__ssh_window_dest" >&2
  return 0
}
