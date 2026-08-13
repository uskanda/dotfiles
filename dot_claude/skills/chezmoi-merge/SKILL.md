---
name: chezmoi-merge
description: dotfiles リポジトリを pull し、$HOME(ライブ) とリポジトリのドリフトを項目ごとに突合してから、ローカルへ chezmoi apply・リモートへ push する。Use when syncing dotfiles across machines, when chezmoi status shows drift, when local $HOME edits need to go back into the repo, or when repo changes need applying to this machine. Keywords: chezmoi apply, chezmoi status, dotfiles sync, drift, pull merge push。
---

# chezmoi-merge

複数端末で dotfiles を運用していると、**リポジトリ側だけ進んだ変更**と
**$HOME 側だけ進んだ変更**が同時に溜まる。このスキルは
`pull → 突合 → apply → push` を一巡させ、どちらの変更も落とさずに収束させる。

> このリポジトリは **public**。commit 前に必ずサニタイズ（手順 6）を通すこと。

## 鉄則

1. **引数なしの `chezmoi apply` を実行しない。** 決定していない項目まで
   $HOME 側の変更を巻き戻す。必ずパスを指定して適用する。
2. **方向を判定してから動く。** 「リポジトリが正」「ライブが正」「双方が育っている
   （union が必要）」の 3 通りがあり、項目ごとに違う。
3. **ユーザーに項目ごとの判断を仰ぐ。** 中身を要約して提示し、勝手に片側へ倒さない。

## 手順

```bash
REPO="$(chezmoi source-path)"; cd "$REPO"
BR="$(git rev-parse --abbrev-ref HEAD)"
```

### 1. 作業ツリーを確認して pull

```bash
git status --porcelain          # 汚れていれば先に commit するかユーザーに確認
git pull --rebase origin "$BR"
```

`dot_claude/settings.json.tmpl` が衝突した場合は、専用の
**sync-claude-settings** スキルに委譲する（allow の union と集約基準はそちらが持つ）。
それ以外のファイルが衝突したら**止めてユーザーに報告**する。

### 2. ドリフトを列挙

```bash
chezmoi status
```

2 列の意味を取り違えないこと:

| 表示 | 意味 |
| ---- | ---- |
| 1 列目 | chezmoi が最後に書いた後、**$HOME 側が変更された** |
| 2 列目 | **apply が行う操作**（`M`=上書き / `A`=新規作成 / `D`=削除） |

`MM` は「両側が動いている」サイン。union が必要な候補。

差分が 0 行なのにドリフト扱いになる項目は、**中身ではなくパーミッションの差**を疑う:

```bash
stat -f '%Sp (%Lp)' ~/Library        # 実際のモード
chezmoi state dump | grep -A2 '"<対象パス>"'   # chezmoi が想定するモード
```

ソース側のディレクトリ名に `private_` が無いと 0755 が目標になり、**apply が
`~/Library` 等のパーミッションを緩めてしまう**。実モードに合わせて `private_` を付ける。

### 3. 項目ごとに方向を判定

**JSON は生 diff を信用しない。** キー順が違うだけで巨大な差分に見える。
描画結果と実ファイルを**意味ベース**で比較する:

```bash
chezmoi cat ~/.claude/settings.json > /tmp/repo.json
cp ~/.claude/settings.json /tmp/live.json
python3 - <<'PY'
import json
live = json.load(open('/tmp/live.json'))
repo = json.load(open('/tmp/repo.json'))
print('ライブにのみあるキー:', sorted(set(live) - set(repo)) or 'なし')
print('リポジトリにのみあるキー:', sorted(set(repo) - set(live)) or 'なし')
for k in sorted(set(live) & set(repo)):
    if live[k] != repo[k]:
        print(f'値が違う: {k}')
PY
```

スクリプト等は**行数・コミット日時・ファイル mtime**で当たりを付け、
最後に必ず「ライブにしか無い行」の中身を読む:

```bash
diff <(chezmoi cat ~/.local/bin/FOO) ~/.local/bin/FOO | grep '^>'
git log -1 --format='%ad %s' --date=short -- dot_local/bin/executable_FOO
```

ライブ固有行が**旧実装の残骸**（リファクタ前の書き方）なら、リポジトリを正にしても
失われるものは無い。**新機能**なら逆か union。ここを読まずに判断しない。

### 4. ユーザーに提示して決定を仰ぐ

項目ごとに「何が違うか」「どちらが新しいか」「推奨」を short に出して選ばせる。
まとめて 1 つの判断に丸めない。

### 5. 決定に従って反映

```bash
# ライブが正 → リポジトリへ取り込む
chezmoi add ~/.claude/skills/foo

# リポジトリが正 → $HOME へ適用（パスを必ず指定）
chezmoi apply --force ~/.local/bin ~/.config/tmux
```

`--force` が要るのは、$HOME 側が変更済みのファイルで chezmoi が上書き確認の
プロンプトを出すため。非対話環境では `could not open a new TTY` で止まる。
**中身を確認し、必要ならバックアップを取ってから**付けること。

**union が要る場合**は、和集合を機械的に作ってから既存のワイルドカードに
包含される冗長エントリだけを落とす。エスケープを手打ちしない
（`json.dumps` で生成した文字列をそのまま使う）。

配布先が OS ごとに違うもの・特定 OS 専用のものは、`.chezmoiignore` に
`{{ if ne .chezmoi.os "..." }}` を書いて振り分ける。

### 6. 検証（commit の前に必ず）

```bash
chezmoi execute-template < dot_claude/settings.json.tmpl | jq -e . >/dev/null && echo "JSON OK"
chezmoi status          # 決定した項目が消えていること
```

- テンプレートは**その端末以外**の描画も確認する（対象が無い端末で
  `lookPath` / `stat` が空になる経路など）。値を差し替えた写しを
  `chezmoi execute-template` に流せば擬似的に再現できる。
- plist は `plutil -lint`、シェルは `bash -n`、Python は `py_compile`。
- **サニタイズ（public 対策）**: ユーザー名・個人プロジェクト名・絶対パス・
  認証情報らしき文字列が tracked ファイルに入っていないか grep する。
  該当したら `~/.claude/settings.local.json`（追跡対象外）へ退避する。
  過去のコミットに入っていないかも確認する: `git log -S '<文字列>' --oneline`

### 7. commit → push

意味のある単位で 2〜3 コミットに分ける（commit スキルの基準に従う）。
`.chezmoiignore` のように複数の関心事にまたがるファイルは、
中間状態を書いてから `git add` することでコミットを分割できる。

```bash
git push origin "$BR"
```

## 落とし穴

- **`chezmoi add --autotemplate` を使わない。** 値の一致だけを見て置換するため、
  XML の `/` を `{{ .chezmoi.pathSeparator }}` に潰し、`StartInterval` の `20` を
  （gid=20 との偶然一致で）`{{ .chezmoi.gid }}` に化けさせる。手書きでテンプレート化する。
- **「ランタイム状態」と決めつけない。** アプリが書き換えるファイル内のキーでも、
  中身を見ると実設定のことがある（例: `tui`、`extraKnownMarketplaces` は
  ユーザーの明示設定）。除外する前に必ず値を読む。
- **ディレクトリのパーミッション**（手順 2 参照）。差分 0 行でも危険。
- chezmoi は**コピー**でありシンボリックリンクではない。$HOME 側の編集は
  `chezmoi add` しない限り次の apply で消える。

## 完了条件

- `chezmoi status` に、判断済み以外のドリフトが残っていない
- テンプレートが全対象 OS で妥当な内容に描画される
- tracked ファイルに秘密・個人情報が無い
- commit 済み・`origin` へ push 済み
