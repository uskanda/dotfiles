---
name: pre-merge
description: CIで実行される各チェックをローカルで事前に実行し、エラーがあれば修正してください。
allowed-tools: Bash, Read, Edit, Write, Grep, Glob
---

# CIチェックのローカル事前実行

CIで実行される各チェックをローカルで事前に実行し、エラーがあれば修正してください。

## 実行方針

1. `.github/workflows/`、`.gitlab-ci.yml`、`Makefile`、`package.json` の scripts 等を確認し、CIで実行されるチェックを把握する
2. プロジェクトのディレクトリ構成（モノレポ・バックエンド/フロントエンド分離等）を確認する
3. 各チェックを順番に実行し、エラーがあれば自動修正する

## チェックの例（プロジェクトに応じて選択）

### Python
- lint: `ruff check .` / `flake8`
- format: `ruff format --check .` / `black --check`
- 型チェック: `mypy`
- テスト: `pytest`

### TypeScript/JavaScript
- lint: `eslint`
- format: `prettier --check`
- 型チェック: `tsc --noEmit`
- テスト: `vitest run` / `jest`

### 共通
- `make lint`、`make test` 等の Makefile ターゲットがあればそちらを優先

## ルール

- 各チェックの結果（pass/fail）を簡潔に報告すること
- エラーを修正した場合は、何を修正したか報告すること
- 修正後に該当チェックを再実行して pass を確認すること
- **全チェック pass 後にコミットは行わない**（コミットは `/commit` で別途行う）
- テスト失敗がコード起因でない場合（DB接続エラー等）はスキップして報告すること
