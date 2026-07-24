# 調査結果: 技術文書規約の既存成果物とライセンス

対象読者: このリポジトリの管理者。
前提知識: Markdown、Git、Claude Code の skill 機構。

日本語技術文書・仕様書・ソースコメントの規約を作るにあたり、たたき台として流用できる公開成果物を調査した。
本ファイルは出典とライセンスの記録であり、規約本文は `rules/` に置く。

## 調査方法と限界

このセッションの実行環境は外部通信が許可リスト方式であり、以下のドメインに到達できなかった。

- `www.bunka.go.jp`（文化庁）— CONNECT が 403
- `developers.google.com` — 403
- `t28.dev`、`www.daiichihoki.co.jp` — 403

到達できた成果物は原文を読み、到達できなかったものは Web 検索の要約と既知情報で補った。
後者は下表の「確認」列で区別する。**「要一次確認」の項目は、規約へ取り込む前に原典を各自の環境で確認すること。**

## 一覧

| # | 成果物 | 提供元 | ライセンス | 確認 | 流用方針 |
|---|--------|--------|-----------|------|---------|
| 1 | [textlint-rule-preset-ja-technical-writing](https://github.com/textlint-ja/textlint-rule-preset-ja-technical-writing) | textlint-ja (azu) | MIT | 原文 | **中核**。ルール名と既定値をそのまま規約の数値基準に採用 |
| 2 | [textlint-rule-ja-no-redundant-expression](https://github.com/textlint-ja/textlint-rule-ja-no-redundant-expression) | azu | MIT | 原文 | **中核**。冗長表現の置換表の骨格に採用 |
| 3 | [textlint-rule-ja-no-weak-phrase](https://github.com/textlint-ja/textlint-rule-ja-no-weak-phrase) | azu | MIT | 原文（一部） | 断定規約の根拠に採用 |
| 4 | [textlint-rule-preset-JTF-style](https://github.com/textlint-ja/textlint-rule-preset-JTF-style) | textlint-ja | 実装 MIT | 原文 | 表記（全角・半角、記号、かっこ）の規約に採用 |
| 5 | [JTF日本語標準スタイルガイド（翻訳用）第3.0版](https://www.jtf.jp/tips/styleguide) | 日本翻訳連盟 | CC BY 4.0 | 要一次確認 | #4 の原典。表記規約の出典表示に使う |
| 6 | [公用文作成の考え方（建議）](https://www.bunka.go.jp/seisaku/bunkashingikai/kokugo/hokoku/93657201.html) | 文化審議会（2022-01-07） | 政府標準利用規約 第2.0版（CC BY 4.0 互換） | 要一次確認 | **中核**。専門用語の三分類を用語規約の骨格に採用 |
| 7 | [Google developer documentation style guide](https://developers.google.com/style) | Google | CC BY 4.0（コード例は Apache 2.0） | 要一次確認 | 構造・リンク・時制の規約に採用 |
| 8 | [errata-ai/Google](https://github.com/errata-ai/Google) | errata-ai | CC BY 4.0 | 原文（README） | #7 の機械可読版。将来 Vale を導入するなら実体として使える |
| 9 | [errata-ai/Microsoft](https://github.com/errata-ai/Microsoft) | errata-ai | MIT | 原文（`Wordiness.yml`） | 冗長句 → 簡潔句の対応表を日本語向けに翻案 |
| 10 | [google/styleguide](https://github.com/google/styleguide) | Google | CC BY 3.0 | 原文（README） | 言語別コメント規約の参照先。全文流用はしない |
| 11 | [Diátaxis](https://diataxis.fr/) | Daniele Procida | CC BY-SA 4.0 | 原文（README） | **概念のみ借用**。後述の理由で本文は転記しない |
| 12 | [OpenSpec](https://github.com/Fission-AI/OpenSpec) | Fission-AI | MIT | 原文（README / concepts / conventions spec） | **中核**。成果物ごとの規約をそのまま前提とし、日本語版を重ねる |
| 13 | [MADR](https://github.com/adr/madr) | adr | MIT / CC0 デュアル | 検索のみ | 設計判断の記録（ADR）テンプレとして採用候補 |
| 14 | [anthropics/skills](https://github.com/anthropics/skills) | Anthropic | Apache 2.0（document skills は source-available） | 原文（README） | skill の構造の参考。文書規約そのものは無い |
| 15 | [Skill authoring best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices) | Anthropic | ドキュメント | 原文 | skill の分割方針・記述量の判断基準に採用 |
| 16 | RFC 2119 / RFC 8174 | IETF | IETF Trust | 既知 | 要求レベルのキーワード対応表に採用 |
| 17 | [SmartHR Design System ライティング](https://smarthr.design/products/contents/) | SmartHR | 不明 | 検索のみ | ライセンス不明のため**流用しない**。着想の参考に留める |

## 中核として採る4つ

### 1. textlint-rule-preset-ja-technical-writing（MIT）

日本語技術文書向けの校正ルール集。**規約を数値で書けるのが最大の価値**であり、
「読みやすく書く」のような検証不能な指示を、機械で検査できる基準に置き換えられる。

| ルール | 既定値 | 規約への反映 |
|--------|--------|-------------|
| `sentence-length` | `max: 100` | 一文の上限。技術文書では 90 を推奨値とする |
| `max-ten` | `max: 3` | 一文の読点は3つまで |
| `max-comma` | `max: 3` | 同上（英文用） |
| `max-kanji-continuous-len` | `max: 6` | 漢字の連続は6字まで |
| `no-mix-dearu-desumasu` | 本文と箇条書きで別管理 | 文体の統一 |
| `ja-no-mixed-period` | `。` | 文末記号の統一 |
| `no-double-negative-ja` | 有効 | 二重否定の禁止 |
| `no-doubled-joshi` | `min_interval: 1` | 同一助詞の連続禁止 |
| `no-doubled-conjunction` | 有効 | 同一接続詞の連続禁止 |
| `no-doubled-conjunctive-particle-ga` | 有効 | 接続助詞「が」の重複禁止 |
| `ja-no-weak-phrase` | 有効 | 弱い表現の禁止 |
| `ja-no-redundant-expression` | 有効 | 冗長表現の禁止 |
| `ja-no-successive-word` | 有効 | 同語の連続禁止 |
| `ja-no-abusage` | 有効 | 誤用の検出 |
| `no-exclamation-question-mark` | 有効 | 感嘆符・疑問符の禁止 |
| `no-hankaku-kana` | 有効 | 半角カナの禁止 |
| `arabic-kanji-numbers` | 有効 | 漢数字と算用数字の使い分け |
| `no-nfd` / `no-invalid-control-character` / `no-zero-width-spaces` / `no-unmatched-pair` / `ja-unnatural-alphabet` | 有効 | 文字レベルの検査 |

`ja-no-redundant-expression` が検出する冗長パターンは6種類である。

1. `すること[助詞](不)可能` → 「すること[助詞]」を削る
2. `すること[助詞]できる` → 同上
3. `であると言えます` → どちらかを削る
4. `であると考えている` → どちらかを削る
5. `[サ変名詞]を行う` → `[サ変名詞]する`
6. `[サ変名詞]を実行` → `[サ変名詞]する`

`ja-no-weak-phrase` は「〜かもしれない」「〜と思う」「〜と思います」など、
主張を弱める語尾を検出する。

### 2. 公用文作成の考え方（CC BY 4.0 互換）

**「既知とは言えない用語が未定義のまま使われる」という問題に対する直接の答え**がここにある。
専門用語は次の三つに振り分けて扱う。

| 対応 | 使う場面 | 例 |
|------|---------|---|
| (a) 言い換える | 一般語で意味が保てる | 「頻回に」→「何回も」 |
| (b) 説明を付けて使う | 用語自体が必要 | 「罹災証明書（＝被災の事実を証明する書類）」 |
| (c) そのまま使う | 読み手に確実に通じる | 「ストレス」「ボランティア」「リサイクル」 |

この三分岐は判断が機械的であり、規約として書き下しやすい。
本リポジトリの規約では、(c) の「確実に通じる」を**文書冒頭で宣言した前提知識**に紐付けて判定可能にする。

### 3. Google developer documentation style guide（CC BY 4.0）

言語非依存の構造規約として使う。特に次の四つを採る。

- 結論先行と、条件節の前置（「〜する場合は、〜する」）
- 時制に依存しない記述（「現在」「最新」「新しい」を避け、版と日付で書く）
- 位置参照の禁止（「上記」「下記」ではなく見出し名で参照する）
- 読み手を軽んじる語の禁止（「簡単に」「単に」「もちろん」）

### 4. OpenSpec（MIT）

OpenSpec 自身の規約（`openspec/specs/openspec-conventions/spec.md`）から、日本語版でも維持すべき制約を抽出した。

- `### Requirement: <名前>` の直後に SHALL 文を置き、名前は50字未満で一意にする
- `#### Scenario:` は見出しレベル4で、`**GIVEN** / **WHEN** / **THEN** / **AND**` の太字キーワードを使う
- 要求は**外部から観測できる振る舞い**だけを書き、実装詳細は `design.md` か `tasks.md` に置く
- 差分は `## ADDED / MODIFIED / REMOVED / RENAMED Requirements` で表し、完全な将来像は書かない
- 見出し文字列が要求の一意識別子になるため、正規化後に重複してはならない

**重要な帰結**: 見出しとキーワードは OpenSpec のパーサが依存する構造であり、英語のまま維持しなければならない。
日本語化してよいのは要求名と本文だけである。この線引きは `rules/openspec-ja.md` で明文化した。

## 採らない、または注意して扱うもの

### Diátaxis（CC BY-SA 4.0）

文書を「チュートリアル / ハウツー / リファレンス / 説明」の4種に分ける枠組み。分類の考え方は有用である。
ただし **CC BY-SA は継承条件付き**であり、本文を転記すると本リポジトリの規約文書まで CC BY-SA になる。
分類の名称と考え方はアイデアであって著作物ではないため、**用語だけ借り、説明文はすべて書き下ろす**方針とする。

### SmartHR Design System

日本語の UI ライティング規約として質が高いが、公開ページにライセンス表示を確認できなかった。
**流用しない。**

### Microsoft Writing Style Guide

本文は Microsoft の独自条件であり流用できない。
MIT で公開されている Vale 実装（`errata-ai/Microsoft`）の `Wordiness.yml` のみを参照し、
英語の冗長句 → 簡潔句の対応（`has the ability to` → `can`、`in order to` → `to` など約150件）を
日本語の置換表を作る際の発想の型として使った。日本語の置換表自体は書き下ろしである。

## 出典表示

規約を配布する際は、次の帰属表示を添える。

```
本規約は以下の成果物を参考に作成した。

- 公用文作成の考え方（建議）／文化審議会（政府標準利用規約 第2.0版, CC BY 4.0 互換）
- JTF日本語標準スタイルガイド（翻訳用）／一般社団法人日本翻訳連盟（CC BY 4.0）
- Google developer documentation style guide／Google（CC BY 4.0）
- textlint-rule-preset-ja-technical-writing ほか／textlint-ja（MIT）
- OpenSpec／Fission-AI（MIT）

Diátaxis（CC BY-SA 4.0）については、文書分類の考え方のみを参照し、本文の転載はしていない。
```
