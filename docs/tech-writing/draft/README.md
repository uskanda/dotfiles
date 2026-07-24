# ドラフト（未導入）

[`../proposal.md`](../proposal.md) の暫定の決定に沿って組み立てた試作である。
**まだ導入していない。** 合意後に `dot_claude/skills/` へ移す。

## 中身

| パス | 内容 |
|------|------|
| `tech-writing-ja/SKILL.md` | skill 本体。規約の要点と自己校閲手順 |
| `tech-writing-ja/references/redundancy.md` | 冗長表現の置換表の全文 |
| `tech-writing-ja/references/terminology.md` | 用語の扱いの全文 |
| `CLAUDE.md.snippet.md` | `~/.claude/CLAUDE.md` への追記案（30行以内） |
| `install-draft-skill.sh` | skill を組み立てて配置する |

`references/openspec.md` と `references/code-comments.md` はここに置いていない。
規約本文の正は [`../rules/`](../rules/) にあり、`install-draft-skill.sh` が配置時に複製する。
同じ内容を2箇所で保守しないための処置である。

## 試す

```bash
# 何をするか確認する
./install-draft-skill.sh --dry-run

# ~/.claude/skills/tech-writing-ja へ配置する
./install-draft-skill.sh

# 別の場所に置いて試す
./install-draft-skill.sh --to /tmp/skills/tech-writing-ja
```

配置したら Claude Code を起動し直し、`/tech-writing-ja` で明示的に呼べるか、
日本語の文書を書かせたときに自動で発火するかを見る。

## 外す

```bash
rm -rf ~/.claude/skills/tech-writing-ja
```

chezmoi の管理下には入っていないため、これで元に戻る。

## 試した後に見てほしいこと

[`../proposal.md`](../proposal.md) §8 の段階3にあたる。文書を3本ほど書かせて記録する。

- 発火したか。しなかった場面はどれか
- 人が手を入れた行数の割合
- 規約のうち守られなかった項目の ID
- 逆に、規約が邪魔になった場面
