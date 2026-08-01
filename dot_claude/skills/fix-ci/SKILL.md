---
name: fix-ci
description: 作業中リポジトリの失敗しているCI（GitHub Actions / GitLab CI）を調査し、原因を修正して結果を報告する。引数として数字（MR/PR番号）またはURLを受け取る。
allowed-tools: Bash, Read, Edit, Write, Grep, Glob
---

# CI失敗の調査と修正

作業中のリポジトリに対応する GitHub / GitLab の CI が失敗しているので、エラー内容を確認し、適宜修正して結果を報告してください。

## 引数

引数として **数字** または **URL** を受け取る。

- **数字** … Merge Request 番号（GitLab）/ Pull Request 番号（GitHub）として解釈する。
- **URL** … MR/PR・パイプライン・ジョブのいずれかの URL。そのまま対象を特定するのに使う。
- **引数なし** … 現在チェックアウト中のブランチに紐づく最新の MR/PR またはパイプラインを対象とする。

## ホスティング判定

1. セッション冒頭に注入される `<repo-hosting>` の判定結果をそのまま使う（再判定は不要）。
2. `<repo-hosting>` が無いセッションでのみ、`git remote get-url origin`（無ければ他の remote）
   を確認してホストが GitHub か GitLab かを判定する。
   - GitLab はセルフホストの場合があるため、ドメインだけで決めず remote URL とも突き合わせる。
3. 引数で**別リポジトリの** URL が渡された場合は、そのドメインからの判定を優先する。

## GitLab の場合

`glab` コマンドで Merge Request / Pipeline / Job にアクセスし、エラー内容を把握する。

1. 対象 MR の特定:
   - 数字 → `glab mr view <番号>`
   - URL → URL から MR 番号 or パイプライン/ジョブ ID を抽出
   - 引数なし → `glab mr view`（現在ブランチの MR）
2. 失敗したパイプライン/ジョブの特定:
   - `glab ci status` / `glab ci view` で現在ブランチのパイプライン状況を確認
   - MR に紐づくパイプラインは `glab mr view <番号>` の出力や `glab api` で辿る
3. 失敗ジョブのログ取得:
   - `glab ci trace <job-id>` または `glab job` 系コマンドで失敗ジョブのログを取得する
   - うまく取れない場合は `glab api projects/:id/jobs/<job-id>/trace` を試す
4. ログから失敗原因を特定する。

## GitHub の場合

`gh` コマンドで Pull Request / workflow run / job にアクセスし、エラー内容を把握する。

1. 対象 PR の特定:
   - 数字 → `gh pr view <番号>`
   - URL → URL から PR 番号 or run ID を抽出
   - 引数なし → `gh pr view`（現在ブランチの PR）
2. 失敗した run/job の特定:
   - `gh pr checks <番号>` で失敗しているチェックを確認
   - `gh run list` / `gh run view <run-id>` で run を辿る
3. 失敗ジョブのログ取得:
   - `gh run view <run-id> --log-failed` で失敗ステップのログを取得する
4. ログから失敗原因を特定する。

## 修正方針

1. ログから失敗の根本原因を特定する（lint / format / 型 / テスト / ビルド / 依存関係 など）。
2. 原因がコード起因であれば修正する。可能ならローカルで該当チェックを再現・再実行して直ったことを確認する（`pre-merge` の手順も参考にする）。
3. CI 設定（`.gitlab-ci.yml` / `.github/workflows/`）起因の場合は設定ファイルを修正する。
4. 失敗がコード起因でない場合（インフラ・ネットワーク・外部サービス障害・フレーキーなテスト等）は、推測せずその旨を報告し、必要なら再実行を提案する。

## ルール

- **コミット・push は行わない**（コミットは `/commit`、push は別途ユーザーの指示で行う）。ただしユーザーが明示的に依頼した場合はこの限りでない。
- 修正した内容は「何を・なぜ」直したか簡潔に報告する。
- 複数のジョブが失敗している場合は、それぞれの原因と対応をまとめて報告する。
- ログが長い場合は要点（エラー行・スタックトレース）に絞って引用する。

## 報告形式

1. 対象（MR/PR 番号・URL・ブランチ）
2. 失敗していたジョブと原因
3. 行った修正（ファイルと変更内容）
4. ローカル再確認の結果（実行できた場合）
5. 残課題・次のアクション（push/再実行の要否など）
