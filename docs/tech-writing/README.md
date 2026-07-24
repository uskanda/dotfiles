# 日本語技術文書規約の検討

Claude Code に日本語の技術文書・仕様書・ソースコメントを書かせるための規約を検討している。
目的は、人が校閲する量を減らすことである。

## 読む順

1. [`proposal.md`](proposal.md) — 提案。どこに何を置くか、決めてほしいことは何か
2. [`rules/core-ja.md`](rules/core-ja.md) — 共通規約のドラフト
3. [`rules/openspec-ja.md`](rules/openspec-ja.md) — OpenSpec 成果物向けの追加規約
4. [`rules/code-comments-ja.md`](rules/code-comments-ja.md) — ソースコメント向けの追加規約
5. [`survey.md`](survey.md) — 調査結果。出典とライセンス
6. [`draft/`](draft/) — 提案どおりに組み立てた試作。試すための手順もここにある

急ぐ場合は `proposal.md` の「6. 決めてほしいこと」だけ読めばよい。
先に動かして判断したい場合は `draft/README.md` を読む。

## 状態

議論用のドラフトである。skill としてはまだ導入していない。
`draft/install-draft-skill.sh` で `~/.claude/skills/` へ手動配置して試せる。
合意後に `dot_claude/skills/` へ移す。

## このディレクトリの扱い

chezmoi の適用対象外である（`.chezmoiignore` に登録済み）。
`~/docs/` には展開されない。
