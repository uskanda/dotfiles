#!/bin/bash
# colima docker.sock 自動復旧スクリプト（定期ウォッチドッグ / ウェイク両用）
#
# 背景:
#   colimaはホストの docker.sock を「VM起動時に一度だけ」SSH経由でVMへ中継する。
#   この中継はSSHのControlMaster接続に紐付くため、スリープ復帰・ネットワーク変化・
#   VSCodeのVM再接続など、何らかの理由でマスターが張り直されると docker.sock の
#   Unixソケットforwardだけが失われる（limaは再接続時にTCPポートしか復旧しない）。
#   結果、ソケットファイルは残るが誰も受けていない状態になり、ホストからdockerが
#   無応答になる。VM内のデーモン・コンテナ自体は無傷。OOM/スリープに限らず再発する。
#
# 動作（冪等・非破壊）:
#   1. curlの /_ping でソケット死活を判定。健全なら即終了（最頻路を最軽量に）。
#   2. colima未起動（ユーザが意図的に停止）なら何もしない。
#   3. マスター再接続中の一時的断を避けるため数秒だけ待って再判定。
#   4. なお死んでいれば、SSHマスター経由で forward を張り直す（コンテナは止めない）。
#   5. マスター自体が未確立の時はログのみで次サイクルに委ねる（通知連発を避ける）。
#      マスターは生きているのに張り直しに失敗した稀なケースだけ通知する。
set -u
export PATH=/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin

PROFILE=default
HOSTSOCK="$HOME/.colima/$PROFILE/docker.sock"
SSHCFG="$HOME/.colima/_lima/colima/ssh.config"
SSHHOST=lima-colima
GUESTSOCK=/var/run/docker.sock
LOG="$HOME/.colima/wake-fix-docker.log"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >>"$LOG"; }
notify() { osascript -e "display notification \"$1\" with title \"colima docker復旧\"" >/dev/null 2>&1 || true; }
ping_ok() { curl -s -m 3 --unix-socket "$HOSTSOCK" http://localhost/_ping >/dev/null 2>&1; }

# 健全なら即終了
ping_ok && exit 0

# colima未起動なら何もしない
colima status >/dev/null 2>&1 || exit 0

# 一時的断の可能性があるため数秒だけ待って再判定
for _ in 1 2 3; do
  sleep 2
  ping_ok && exit 0
done

# 再フォワードのクリティカルセクションは排他化する。
# sleepwatcher(ウェイク時)と定期ウォッチドッグが同時起動した際の rm→forward 競合を防ぐ。
# 60秒以上前のロックは異常終了の残骸とみなして掃除する（正常実行は十数秒で終わる）。
LOCKDIR="$HOME/.colima/.wake-fix.lock"
[ -d "$LOCKDIR" ] && [ -n "$(find "$LOCKDIR" -prune -mmin +1 2>/dev/null)" ] && rmdir "$LOCKDIR" 2>/dev/null
mkdir "$LOCKDIR" 2>/dev/null || exit 0
trap 'rmdir "$LOCKDIR" 2>/dev/null' EXIT

# ロック取得待ちの間に他インスタンスが復旧済みかもしれないので再確認
ping_ok && exit 0

log "docker.sock dead; attempting lightweight re-forward"
if ssh -F "$SSHCFG" -O check "$SSHHOST" >/dev/null 2>&1; then
  rm -f "$HOSTSOCK"
  if ssh -F "$SSHCFG" -O forward -L "$HOSTSOCK":"$GUESTSOCK" "$SSHHOST" >/dev/null 2>&1 && { sleep 1; ping_ok; }; then
    log "re-forward OK"
    exit 0
  fi
  log "re-forward attempted but socket still dead"
  notify "docker.sockの再フォワードに失敗。'colima restart' が必要かもしれません。"
else
  log "ssh master not alive yet; will retry next cycle"
fi
exit 1
