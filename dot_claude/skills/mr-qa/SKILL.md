---
name: mr-qa
description: 現在の作業ブランチをリモートにpushし、qaブランチへのマージリクエストをGitLab CLIで作成してください。pushしたブランチは削除しないこと。
allowed-tools: Bash
---

# 現在のブランチからqaへのマージリクエスト作成

現在の作業ブランチを `origin` にpushし、そのブランチから `qa` ブランチへのマージリクエストをGitLab CLIで作成してください。

**重要**: pushしたソースブランチは削除しないこと。QA確認後に develop などへ進めるため、ブランチを残す。ただし本プロジェクト `at/chime/alex` は**マージ時のソースブランチ削除が既定ON**のため、明示的な無効化が必要。

無効化には次の2点に注意する:

1. `glab mr merge` に `--remove-source-branch` を付けないだけでは不十分（既定ONのため）。
2. `glab mr update <MR_ID> --remove-source-branch=false` は**環境によって反映されない**（実行後も MR の `force_remove_source_branch` が `true` のまま残ることを確認済み）。このフラグを信用してそのままマージすると、qaマージでソースブランチが削除される。

このため下記手順では、**GitLab API で確実に無効化し、マージ前に必ず検証（`force_remove_source_branch` が `false` であること）してからマージする**。検証で `false` にできない場合は**マージせず中断**し、ユーザーに報告すること。

## タイトル形式

`qa YYYYMMDD HH:MM` 形式で現在時刻を使用する（例: `qa 20260311 14:30`）

## 説明文

qaブランチと現在のブランチの差分に含まれるすべての変更を機能単位でリストアップして記載する。
直近の修正だけでなく、qaに未マージのすべての差分を対象とすること。

## 手順

1. `git branch --show-current` で現在のブランチ名を取得する
2. 現在のブランチを `origin` にpushする: `git push -u origin "$(git branch --show-current)"`
3. 現在時刻をJSTで取得してタイトルを生成する: `TZ=Asia/Tokyo date '+%Y%m%d %H:%M'`
4. `git log --oneline origin/qa..HEAD` でqaと現在のブランチの差分コミット一覧を取得
5. 差分コミットの内容から機能・修正をリストアップして説明文を生成する
6. 以下のコマンドでマージリクエストを作成する:
   ```
   glab mr create \
     --source-branch "$(git branch --show-current)" \
     --target-branch qa \
     --title "qa $(TZ=Asia/Tokyo date '+%Y%m%d %H:%M')" \
     --description "<生成した説明文>" \
     --yes
   ```
7. 作成されたMRのID（URLの末尾の数字）を取得する。以降のAPI呼び出し用に、origin のURLからプロジェクトパスをURLエンコードして変数化する:
   ```
   PROJ=$(git remote get-url origin | sed -E 's#^(https?://[^/]+/|git@[^:]+:|ssh://git@[^/]+/)##; s#\.git$##' | sed 's#/#%2F#g')
   ```
8. **ソースブランチ削除を GitLab API で確実に無効化する**（`glab mr update --remove-source-branch=false` は反映されないことがあるため API を使う）:
   ```
   glab api --method PUT "projects/$PROJ/merge_requests/<MR_ID>" -f "remove_source_branch=false"
   ```
9. **検証ゲート（必須）**: MR の `force_remove_source_branch` が `false` になっていることを確認する:
   ```
   glab api "projects/$PROJ/merge_requests/<MR_ID>" \
     | python3 -c "import sys,json;print(json.load(sys.stdin).get('force_remove_source_branch'))"
   ```
   - 出力が `False` の場合のみ次のマージ手順へ進む。
   - `True`（またはエラー）の場合は**マージを実行せず中断**し、ユーザーに報告する。そのままマージするとソースブランチが削除されるため、絶対にマージしないこと。
10. auto-mergeを有効にする（**`--remove-source-branch` は付けない**＝ソースブランチを残す）:
    ```
    glab mr merge <MR_ID> --auto-merge --yes
    ```
11. マージ後、ソースブランチが `origin` に残っていることを確認してから、マージリクエストのURLを出力する:
    ```
    git ls-remote --heads origin "$(git branch --show-current)"
    ```
