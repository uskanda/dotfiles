# 提案: 日本語技術文書規約の skill 構成

対象読者: このリポジトリの管理者。
前提知識: Claude Code の skill と CLAUDE.md、chezmoi によるこのリポジトリの運用。

本ファイルは**どこに何を置くか**と**何を決めたか**を扱う。
調査結果は [`survey.md`](survey.md)、規約本文は
[skill](../../dot_claude/skills/tech-writing-ja/) にある。

---

## 1. 課題の整理

依頼にあった2つの不満を、規約で対処できる形に分解した。

| 不満 | 原因 | 対処 |
|------|------|------|
| 日本語が冗長 | (a) 定型の冗長句（「〜することができます」型）<br>(b) 同じ内容の繰り返し（概要・詳細・まとめ）<br>(c) 内容のない前置きと締め<br>(d) 根拠のない三つ組の列挙 | 置換表と禁止リストで機械的に潰す（W-200〜W-211） |
| 既知でない用語が未定義 | 読み手の前提知識が定義されていないため、既知かどうかを判定できない | 文書冒頭で**前提知識を宣言**させ、そこに無い語は初出時に定義を必須にする（W-400、W-401） |

(b) と用語の問題は、**判定基準がないこと**が根本原因である。
「冗長にしない」「難しい用語を避ける」という指示は判定できないため守られない。
判定できる基準に置き換えることが、本規約の設計方針である。

### 効果の例

規約適用前（典型的な出力）:

> ## 認証機能の実装について
>
> 本セクションでは、認証機能の実装について説明します。認証機能とは、ユーザーが
> システムにアクセスする際に、そのユーザーが正当な利用者であるかどうかを確認する
> ための機能のことです。本システムでは、JWT を利用した認証を実装することにより、
> セキュリティの向上、保守性の向上、拡張性の向上を実現することが可能となっています。
> 具体的には、以下のような実装を行っています。

規約適用後:

> ## 認証
>
> JWT（JSON Web Token、署名付きの認証情報）で認証する。
> セッションを server 側に保持しないため、API server を水平に増やせる。

225字が82字になり、削られた情報は無い。
削除したのは、見出しの言い換え（W-203）、既知語の説明（W-401(c)）、
根拠のない三つ組（W-205）、冗長句（W-200）である。
一方で、読み手が知らない可能性のある JWT には定義を足した（W-401(b)）。

## 2. なぜ skill だけでは足りないか

執筆規約は**Claude が日本語を書くたびに適用される必要がある**。
一方、skill は description との照合で発火する。この二つは噛み合わない。

| 置き場所 | 適用の確実性 | context の消費 | 向く内容 |
|---------|------------|--------------|---------|
| `~/.claude/CLAUDE.md` | 常に適用される | 常時消費する | 短く、常に効かせたい規約 |
| skill の `SKILL.md` | 発火したときだけ | 発火時のみ | 手順、判断表、詳細規約 |
| skill の `references/` | 参照したときだけ | 参照時のみ | 長い一覧、用途別の追加規約 |
| hook（textlint） | 決定的に適用される | しない | 機械で検査できる項目 |

そこで**3層に分ける**。

```
第0層  CLAUDE.md（常時・30行以内）
        └ 守らせたい規約の中核だけ。文体・冗長句・用語定義・コメント。

第1層  skill tech-writing-ja（文書を書く／直すときに発火）
        ├ SKILL.md          規約本体と自己校閲手順
        └ references/       置換表、用語、OpenSpec、コメント、校閲手順

第2層  textlint + hook（任意・決定的）
        └ .md の保存時に機械検査。人の校閲を最後の砦にしない。
```

第0層は「効かせる」ため、第1層は「正確に書かせる」ため、第2層は「検査する」ためにある。
どれか一つでは目的を達しない。

## 3. skill の分割（案C を採用）

### 案A: 単一 skill

```
tech-writing-ja/
├── SKILL.md
└── references/{redundancy,terminology,openspec,code-comments,review}.md
```

- 長所: 発火判定が1回で済む。用語と文体が一貫する。
- 短所: description が広くなり、コード編集中にも発火しうる。

### 案B: 用途別に3 skill

`tech-writing-ja` / `openspec-ja` / `code-comments-ja` に分ける。

- 長所: 発火条件が明確で、それぞれが短い。
- 短所: 共通規約が3箇所に重複する。共通部分をファイルに切り出すと参照が2階層になり、
  Claude が部分読みする恐れがある（Anthropic は参照を1階層に保つよう推奨している）。

### 案C: 執筆と校閲を分ける（**採用**）

```
tech-writing-ja/          # 書くとき
├── SKILL.md
└── references/{redundancy,terminology,openspec,code-comments}.md

doc-review-ja/            # 既存文書を直すとき（明示起動を想定）
└── SKILL.md
```

- 「書く」と「直す」で必要な手順が違う。校閲では原文の意図を変えずに差分で示し、
  指摘に規約 ID を添える必要がある。この手順を執筆用 skill に混ぜると SKILL.md が濁る。
- コメント規約は文書 skill の参照ファイルに置きつつ、**要点だけ第0層にも置く**。
  コーディング中に skill が発火しない前提で設計する。

案C を採用した。`tech-writing-ja` のみ配置済みで、`doc-review-ja` は段階4で足す。
効果を測る前に skill を増やさない。

## 4. 各層に置く内容

### 第0層: `~/.claude/CLAUDE.md`

追記する本文は [`CLAUDE.md.snippet.md`](CLAUDE.md.snippet.md) にある。16項目、30行以内。
反映は手作業で行う。理由は §5 に書いた。

### 第1層: `dot_claude/skills/tech-writing-ja/`

配置済みである。実物を読む。

| ファイル | 役割 | 読ませる場面 |
|---------|------|------------|
| [`SKILL.md`](../../dot_claude/skills/tech-writing-ja/SKILL.md) | 規約本体（`W-*` 54項目）と自己校閲手順 | 発火時に必ず |
| [`references/redundancy.md`](../../dot_claude/skills/tech-writing-ja/references/redundancy.md) | 冗長表現の置換表の全文 | 置換表の全文が要るとき |
| [`references/terminology.md`](../../dot_claude/skills/tech-writing-ja/references/terminology.md) | 用語の扱いの全文（`W-406`〜`W-408`） | 用語集を作るとき、外来語の判断に迷うとき |
| [`references/openspec.md`](../../dot_claude/skills/tech-writing-ja/references/openspec.md) | `OS-*` 30項目 | OpenSpec の成果物を書くとき |
| [`references/code-comments.md`](../../dot_claude/skills/tech-writing-ja/references/code-comments.md) | `C-*` 27項目 | コメントと docstring を書くとき |

参照は1階層に保った。2階層にすると Claude が部分読みする。

規約 ID の `W-108`（感嘆符と疑問符の禁止）は `W-209` に統合したため欠番である。

### 第2層: textlint（opt-in、未着手）

- 導入は opt-in とする。未導入の環境では `SKILL.md` §7 の grep で代替する
- 設定はプロジェクトごとに `.textlintrc.json` を置く。dotfiles には共通設定を置かない
- 推奨する最小構成は `SKILL.md` §9（W-800、W-801）にある
- `PostToolUse` hook による自動実行は段階4で検討する

## 5. ファイル構成

```
dot_claude/skills/tech-writing-ja/     # 配置済み
├── SKILL.md
└── references/{redundancy,terminology,openspec,code-comments}.md

docs/tech-writing/                     # chezmoi の適用対象外
├── README.md
├── proposal.md                        # 本ファイル
├── survey.md
└── CLAUDE.md.snippet.md               # 手作業で追記する本文

（未着手）
dot_claude/skills/doc-review-ja/       # 段階4
```

`docs/` は `~/docs/` に展開されるため `.chezmoiignore` に登録した。

### CLAUDE.md を自動で反映しない理由

`dot_claude/CLAUDE.md` をこのリポジトリに置くと、`chezmoi apply` が各端末の
`~/.claude/CLAUDE.md` を**上書きする**。既存の記述を失う恐れがあるため、
リポジトリには追記用の本文だけを置き、反映は各自が手で行う。
このリポジトリの README にある allowlist 方針と同じ扱いである。

```bash
$EDITOR ~/.claude/CLAUDE.md        # snippet の中身を末尾に追記する
chezmoi add ~/.claude/CLAUDE.md    # ソースへ取り込む
chezmoi diff                       # 差分を確認する
```

## 6. 決定事項

| # | 論点 | 決定 | 状態 |
|---|------|------|------|
| 1 | 文体の既定 | 常体（である調）。手順書と README は敬体を許可 | **決定** |
| 2 | skill の分割 | 案C（執筆 + 校閲）。段階4まで執筆のみ | **決定** |
| 5 | textlint の導入 | opt-in。未導入の環境では grep で代替する | **決定** |
| 3 | CLAUDE.md の分量 | 30行以内（実装は16項目） | 暫定 |
| 4 | コメントの言語 | 既存に合わせる。混在なら日本語。公開 OSS は英語 | 暫定 |
| 6 | skill 名 | `tech-writing-ja`（英語 kebab-case） | 暫定 |
| 7 | 置き場所 | `~/.claude`（全 project 共通） | 暫定 |
| 8 | 「20%削減」の強制度 | 必須。できなければ理由を1行報告（W-211、W-701） | 暫定 |
| 9 | 規約からの逸脱 | 規約 ID と理由を報告に書く（W-702） | 暫定 |
| 10 | 適用対象に PR / issue / commit を含めるか | 含める（本文のみ。commit の1行目は既存の `commit` skill に従う） | 暫定 |

暫定の6件は運用に支障がないため、段階3の測定結果を見てから確定する。

## 7. 未検証の事項

- **OpenSpec の SHALL 検出**（OS-203）: 要求本文を日本語で書いた場合に
  `openspec validate` が要求レベル語を検出できるかを確認していない。
  英語キーワードの括弧併記で通るかは、導入時に1回実行して確かめる。
- **公用文作成の考え方の原文**: 実行環境から `www.bunka.go.jp` に到達できず、
  検索結果の要約に依拠した。専門用語の三分類の記述は原典で確認したい。
- **skill の発火精度**: description の書き方で発火率が変わる。
  実運用で発火しない場面が出たら description を調整する。

## 8. 進め方

| 段階 | 作業 | 完了の判定 | 状態 |
|------|------|-----------|------|
| 1 | 本提案の合意。論点 1、2、5 の決定 | 決定が §6 に反映されている | **完了** |
| 2 | `tech-writing-ja` skill の配置 | `chezmoi apply` が通る | **完了** |
| 3 | 効果の測定 | 文書を3本書かせ、人が手を入れた行数の割合を記録する | 未着手 |
| 4 | `doc-review-ja` と textlint の追加 | 段階3の割合が下がる | 未着手 |

段階2の残作業は `~/.claude/CLAUDE.md` への追記だけである。
上書きの危険があるため自動化していない（§5 参照）。

段階3の測定は、規約が目的（校閲を最小限にする）に効いているかを判定する唯一の手段である。
規約を増やす前に必ず行う。記録する項目は次の4つとする。

- skill が発火したか。しなかった場面はどれか
- 人が手を入れた行数の割合
- 守られなかった規約の ID
- 逆に、規約が邪魔になった場面
