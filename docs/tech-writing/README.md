# 日本語技術文書規約の検討記録

Claude Code に日本語の技術文書・仕様書・ソースコメントを書かせるための規約を作った。
目的は、人が校閲する量を減らすことである。

規約の実物は [skill](../../dot_claude/skills/tech-writing-ja/) にある。
このディレクトリは検討の経緯と、決定の根拠を残すためにある。

## 読む順

| ファイル | 内容 |
|---------|------|
| [`proposal.md`](proposal.md) | 提案と決定事項。3層構成の理由、決定10件、進め方 |
| [`CLAUDE.md.snippet.md`](CLAUDE.md.snippet.md) | `~/.claude/CLAUDE.md` へ手で追記する本文 |
| [`survey.md`](survey.md) | 調査結果。出典17件とライセンス |

規約そのものを読みたい場合は `proposal.md` を飛ばして skill を読む。

## 状態

| 段階 | 内容 | 状態 |
|------|------|------|
| 1 | 提案の合意 | 完了 |
| 2 | skill の配置 | 完了。`~/.claude/CLAUDE.md` への追記だけ手作業で残っている |
| 3 | 効果の測定 | 未着手 |
| 4 | `doc-review-ja` と textlint の追加 | 未着手 |

## 有効にする

skill は `chezmoi apply` で反映される。

```bash
chezmoi diff                 # 反映前に差分を確認する
chezmoi apply ~/.claude
```

CLAUDE.md は上書きの危険があるため自動化していない。
[`CLAUDE.md.snippet.md`](CLAUDE.md.snippet.md) の手順に従う。

## このディレクトリの扱い

chezmoi の適用対象外である（`.chezmoiignore` に登録済み）。`~/docs/` には展開されない。
