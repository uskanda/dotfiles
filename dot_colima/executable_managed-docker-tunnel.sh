#!/bin/bash
# colima docker.sock 専用の自前SSHトンネル（lima非依存）+ 観測ロギング
#
# 背景:
#   colimaのlimaは docker.sock(unix socket) のforwardを「VM起動時に一度だけ」張り、
#   内部のforward refresh ではTCPしか作り直さない。さらに lima は `-F /dev/null` で
#   ssh_configを完全無視するため、ホスト側からKeepAlive等を注入できなかった。
#   結果として docker.sock forward だけが頻繁に失われていた。
#
# 解決（症状側）:
#   limaに頼らず本スクリプトが直接 docker.sock を所有する。
#   launchd KeepAlive=true で死んだら即座に再起動される。
#
# 観測（根本原因究明のためのロギング）:
#   - ssh側に LogLevel=VERBOSE を付与し、切断理由を stderr ログに残す
#   - ラッパー側で各サイクルの「開始→終了→継続時間→直近のpmset抜粋」を
#     EVENTLOG に記録し、後から原因を相関分析できるようにする
#
# SSHオプション:
#   - ServerAliveInterval=30 / ServerAliveCountMax=3: 90秒応答なしで即exit
#   - ExitOnForwardFailure=yes: forward失敗で即終了
#   - StreamLocalBindUnlink=yes: 既存ソケットを掴み直す
#   - ControlMaster=no / ControlPath=none: limaのmuxと完全分離
set -u
export PATH=/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin

PROFILE=default
HOSTSOCK="$HOME/.colima/$PROFILE/docker.sock"
SSHCFG="$HOME/.colima/_lima/colima/ssh.config"
SSHHOST=lima-colima
EVENTLOG="$HOME/.colima/tunnel-events.log"
ERRLOG="$HOME/.colima/docker-tunnel.err.log"

elog() { echo "$(date '+%Y-%m-%dT%H:%M:%S%z') $*" >>"$EVENTLOG"; }

# colima未起動時は短く待って終了（launchd ThrottleIntervalで再試行）
for _ in 1 2 3 4 5 6; do
  [ -f "$SSHCFG" ] && colima status >/dev/null 2>&1 && break
  sleep 5
done
[ -f "$SSHCFG" ] || { elog "abort: ssh.config not found"; exit 1; }
colima status >/dev/null 2>&1 || { elog "abort: colima not running"; exit 1; }

elog "tunnel-start wrapper_pid=$$"
start_ts=$(date +%s)

ssh -F "$SSHCFG" \
  -o ControlMaster=no \
  -o ControlPath=none \
  -o ServerAliveInterval=30 \
  -o ServerAliveCountMax=3 \
  -o ExitOnForwardFailure=yes \
  -o StreamLocalBindUnlink=yes \
  -o LogLevel=VERBOSE \
  -N \
  -L "$HOSTSOCK":/var/run/docker.sock \
  "$SSHHOST" &
SSH_PID=$!

# launchd からの停止シグナルは子ssh にも伝播させて綺麗に終わる
trap 'kill -TERM "$SSH_PID" 2>/dev/null; wait "$SSH_PID" 2>/dev/null; exit' TERM INT

wait "$SSH_PID"
exit_code=$?
end_ts=$(date +%s)
duration=$((end_ts - start_ts))

elog "tunnel-exit code=$exit_code duration=${duration}s"

# 切断時の相関スナップショット
{
  echo "  recent ssh stderr (last 20 lines):"
  tail -n 20 "$ERRLOG" 2>/dev/null | sed 's/^/    /'
  echo "  pmset events in last 120s:"
  pmset -g log 2>/dev/null \
    | awk -v cutoff="$(date -v-120S '+%Y-%m-%d %H:%M:%S')" 'NR>4 && $1" "$2 >= cutoff' \
    | head -n 20 | sed 's/^/    /'
  echo "  ---"
} >>"$EVENTLOG"

exit "$exit_code"
