---
name: mr-qa
description: 現在の作業ブランチをリモートにpushし、qaブランチへのマージリクエストをGitLab CLIで作成してください。pushしたブランチは削除しないこと。
allowed-tools: Bash
---

# 現在のブランチからqaへのマージリクエスト作成

現在の作業ブランチを `origin` にpushし、そのブランチから `qa` ブランチへのマージリクエストをGitLab CLIで作成してください。

**重要**: pushしたソースブランチは削除しないこと。QA確認後に develop などへ進めるため、ブランチを残す。`glab mr merge` で `--remove-source-branch` を**付けない**こと。

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
7. 作成されたMRのID（URLの末尾の数字）を取得する
8. 5秒待つ: `sleep 5`
9. auto-mergeを有効にする（**`--remove-source-branch` は付けない**＝ソースブランチを残す）:
   ```
   glab mr merge <MR_ID> --auto-merge --yes
   ```
10. 作成されたマージリクエストのURLを出力する
