---
name: pr
description: mr スキルのエイリアス。このブランチの修正内容を日本語テキストにまとめ、develop 向けのプルリクエスト(GitHub)／マージリクエスト(GitLab)を作成してください。
allowed-tools: Bash, Read, Grep, Glob
---

# pr（`mr` スキルのエイリアス）

このスキルは `mr` と**完全に同一の挙動**。手順の二重管理を避けるため、本体は `mr` 側にのみ置く。

1. `mr` の本体を読む: `~/.claude/skills/mr/SKILL.md`
   - $HOME が異なる環境（devcontainer 等）で見つからない場合は、Glob で
     `**/.claude/skills/mr/SKILL.md` を探して読む。
2. 読み込んだ手順どおりに実行する（引数が渡されていればそのまま引き継ぐ）。
   プラットフォームは `<repo-hosting>` の判定結果に従い、GitHub なら `gh`、GitLab なら `glab` を使う。
