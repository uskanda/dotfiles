#!/usr/bin/env bash
# tech-writing-ja skill のドラフトを組み立てて配置する。
#
# references/ のうち openspec.md と code-comments.md は ../rules/ から複製する。
# 規約本文の正は ../rules/ 側にあり、このスクリプトは複製の向きを一方向に固定する。
#
#   ./install-draft-skill.sh                 # ~/.claude/skills/tech-writing-ja へ配置
#   ./install-draft-skill.sh --to <dir>      # 配置先を指定
#   ./install-draft-skill.sh --dry-run       # 何をするか表示するだけ
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
src="$here/tech-writing-ja"
rules="$here/../rules"
dest="${HOME}/.claude/skills/tech-writing-ja"
dry=0

while [ $# -gt 0 ]; do
  case "$1" in
    --to) dest="$2"; shift 2 ;;
    --dry-run) dry=1; shift ;;
    -h|--help) sed -n '2,10p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "不明な引数: $1" >&2; exit 2 ;;
  esac
done

[ -f "$src/SKILL.md" ] || { echo "SKILL.md が見つからない: $src" >&2; exit 1; }
[ -f "$rules/openspec-ja.md" ] || { echo "規約本文が見つからない: $rules" >&2; exit 1; }

run() {
  if [ "$dry" -eq 1 ]; then printf '  %s\n' "$*"; else "$@"; fi
}

echo "配置先: $dest"
run mkdir -p "$dest/references"
run cp "$src/SKILL.md" "$dest/SKILL.md"
run cp "$src/references/redundancy.md" "$dest/references/redundancy.md"
run cp "$src/references/terminology.md" "$dest/references/terminology.md"

# ../rules/ から複製し、SKILL.md への参照に書き換える。
for pair in "openspec-ja.md:openspec.md" "code-comments-ja.md:code-comments.md"; do
  from="${pair%%:*}"; to="${pair##*:}"
  if [ "$dry" -eq 1 ]; then
    printf '  sed ... %s -> %s\n' "$rules/$from" "$dest/references/$to"
  else
    sed -e 's|\[`core-ja.md`\](core-ja.md)|`../SKILL.md`|g' \
        -e 's|^skill `tech-writing-ja` の参照ファイル.*$|`../SKILL.md` の共通規約に加えて適用する。|' \
        "$rules/$from" > "$dest/references/$to"
  fi
done

echo "完了。次で確認する:"
echo "  ls -R \"$dest\""
echo
echo "CLAUDE.md への追記は draft/CLAUDE.md.snippet.md を参照する。"
