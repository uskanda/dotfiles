---
name: sync-claude-settings
description: 複数台の ~/.claude を chezmoi で同期する際に settings.json.tmpl（特に permissions.allow）の衝突を解決し、merge→commit→push まで一気に行う。Use when settings.json.tmpl conflicts on git pull/rebase, or when syncing/merging Claude Code permission (allow) settings across machines and pushing the result. Keywords: chezmoi conflict, settings.json.tmpl merge, permission sync, dotfiles。
---

# sync-claude-settings

複数台で Claude Code (`~/.claude`) を chezmoi 管理・同期していると、各端末が
`~/.claude/settings.json` に許可を追記するため、ソースの
`dot_claude/settings.json.tmpl`（特に `permissions.allow`）が頻繁に衝突する。
このスキルは衝突を所定の基準でマージし、push まで自動で行う。

> このリポジトリは **public**。`allow` に端末依存の絶対パス・ユーザー名・
> 個人プロジェクト名を**絶対に公開コミットしない**こと（下記サニタイズ参照）。

## マージ基準（このスキルの核）

1. **remote と local の変更は両方取り込む（union）**。特に `permissions.allow` は
   どちらの追加も落とさず和集合にする。スカラー値（`model` 以外の `theme` 等）は
   ローカル live を優先。`model` は常にテンプレート（`{{ $model | quote }}`）を維持。
2. **特定ディレクトリ依存のコマンド許可は、リスクを検討した上で `*` に集約**する。
   - 集約してよい例（低リスク・読み取り/同一ワークフローの引数違い）:
     `git *`, `apt-cache *`, `dpkg-deb -c *`, `grep -iE *`, `fc-list*`,
     `<venv>/bin/python -m py_compile *`（構文チェック）, `<venv>/bin/pyinfra *` など。
   - **集約してはいけない**（個別のまま残す）: `rm` / `cp` 等の破壊・上書き系、
     `python -c "…"` の任意コード実行、`gh *` / `chezmoi *` のような副作用の広い
     サブコマンド一括（`gh auth *` `gh repo *` `chezmoi --version` 等にスコープ）。
3. **マージ後は commit → push まで一気に**行う（下記手順 6）。

## サニタイズ（public 対策・最重要）

tracked な tmpl には**汎用パターンのみ**を残す。次は tmpl から除外する:

- 絶対パスやユーザー名を含むもの（例: `/home/<user>/…`、`Read(//home/<user>/**)`）
- 個人プロジェクト名を含む相対パス（例: `MyProj/venv/bin/...`）

これらで機能を残したい場合は、**gitignore 済みの `~/.claude/settings.local.json`
（端末ローカル・非公開・非同期）** に退避する。`.chezmoiignore` に
`.claude/settings.local.json` があることを前提とする。Claude Code は実行時に
`settings.json` と `settings.local.json` をマージするため機能は保たれる。

## 前提プリミティブ

- 任意バージョンの tmpl を JSON に描画: `chezmoi execute-template < FILE`、
  あるいは `git show <ref>:dot_claude/settings.json.tmpl | chezmoi execute-template`
- ライブ設定: `~/.claude/settings.json`（こちらは Claude Code が随時書き換える）

## 手順

```bash
set -e
REPO="$(chezmoi source-path)"; cd "$REPO"
BR="$(git rev-parse --abbrev-ref HEAD)"        # 通常 master
TMPL=dot_claude/settings.json.tmpl
```

### 1. リモート取得 & 他ファイルの衝突確認
```bash
git fetch origin
git rebase "origin/$BR" || true               # 競合したら次へ
```
- `git status` で競合が **`$TMPL` 以外**にもあれば、**作業を止めてユーザーに確認**。
- `$TMPL` のみの競合（または競合なし）なら続行。

### 2. tmpl 競合の解決（union）
競合中なら ours/theirs を描画して和集合を取る。競合が無ければこの 2 ソースは
「現在の tmpl」と「origin の tmpl」に読み替える。
```bash
# 競合時:
git show :2:"$TMPL" | chezmoi execute-template > /tmp/ours.json     # ローカル側
git show :3:"$TMPL" | chezmoi execute-template > /tmp/theirs.json   # remote 側
# 競合が無い場合:
# chezmoi execute-template < "$TMPL" > /tmp/ours.json
# git show "origin/$BR:$TMPL" | chezmoi execute-template > /tmp/theirs.json
```

### 3. ローカル live の追記分も取り込む
```bash
cat ~/.claude/settings.json > /tmp/live.json
```

### 4. union → サニタイズ → 集約 → tmpl 再生成
```bash
# allow と additionalDirectories は和集合、スカラーは live 優先で deep-merge
ALLOW=$(jq -s '[.[].permissions.allow[]?] | unique' /tmp/ours.json /tmp/theirs.json /tmp/live.json)
ADD=$(jq -s '[.[].permissions.additionalDirectories[]?] | unique' /tmp/ours.json /tmp/theirs.json /tmp/live.json)
SCAL=$(jq -s 'reduce .[] as $x ({}; . * $x) | del(.permissions)' /tmp/ours.json /tmp/theirs.json /tmp/live.json)
```
ここで `$ALLOW`（JSON 配列）に対して **判断を伴う 2 工程**を行う:

- **サニタイズ**: 端末依存・個人情報を含むエントリを `$ALLOW` から除外し、
  それらは `~/.claude/settings.local.json` の `permissions.allow` に union で退避。
  ```bash
  # 例: 除外したエントリ一覧を /tmp/local_only.json (JSON配列) に用意してから
  LOCAL=~/.claude/settings.local.json
  [ -f "$LOCAL" ] && B=$(cat "$LOCAL") || B='{}'
  echo "$B" | jq --argjson add "$(cat /tmp/local_only.json)" \
    '.permissions.allow = ((.permissions.allow // []) + $add | unique)' > "$LOCAL.tmp" && mv "$LOCAL.tmp" "$LOCAL"
  ```
- **集約**: 上記「マージ基準 2」に従い、ディレクトリ違いだけの低リスク許可を `*` に
  まとめ、冗長な下位 `Read` サブセットを削除（例: `Read(//etc/samba/**)` は
  `Read(//etc/**)` があれば削除）。破壊系・任意コード実行は集約しない。

最終 `$ALLOW`（サニタイズ・集約後）で tmpl を再生成する:
```bash
MERGED=$(jq -n --argjson s "$SCAL" --argjson al "$ALLOW" --argjson ad "$ADD" \
  '$s + {permissions: ({allow:$al} + (if ($ad|length)>0 then {additionalDirectories:$ad} else {} end))}')

# テンプレヘッダ（$model 行まで）を保持し、本体を差し込む。model はテンプレ化を維持。
awk '{print} /\$model :=/{exit}' "$TMPL" > /tmp/tmpl.new
echo "$MERGED" | jq -S '.model = "__MODEL__"' \
  | sed 's/"__MODEL__"/{{ $model | quote }}/' >> /tmp/tmpl.new
mv /tmp/tmpl.new "$TMPL"
```

### 5. 検証 & 適用
```bash
chezmoi execute-template < "$TMPL" | jq -e . >/dev/null && echo "tmpl OK"
# public に個人情報が残っていないか必ず確認（0 件であること）:
chezmoi execute-template < "$TMPL" | jq -r '.permissions.allow[]' | grep -nE '/home/|<your-username>|個人プロジェクト名' && echo "STOP: 個人情報残存" || echo "clean"
# ローカル live を tracked に合わせる（任意。他ファイルで TTY 確認を求められたら個別対応）
chezmoi apply ~/.claude 2>/dev/null || echo "apply は手動確認が必要（settings.json 部分は反映済みか確認）"
```
> `<your-username>` と個人プロジェクト名は実際の値に置き換えて grep すること。

### 6. commit & push（一気に）
```bash
# rebase 中だった場合は続行
git add "$TMPL"
git rebase --continue 2>/dev/null || true

git add "$TMPL"
git commit -m "Sync ~/.claude permissions across machines (union merge + consolidate)" \
  -m "" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
git push origin HEAD
```
> remote は `origin`（このリポジトリは GitHub）。別 remote（GitLab 等）を使う場合は
> `git remote -v` を確認し push 先を読み替える。

## 完了条件
- `chezmoi execute-template < $TMPL` が有効な JSON を返す
- tmpl の `allow` に個人情報・絶対パスが無い（grep で 0 件）
- remote/local 双方の許可が `allow` に揃っている（union 済み）
- commit 済み・`origin` へ push 済み
