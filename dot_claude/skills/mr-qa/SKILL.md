---
name: mr-qa
description: 現在の作業ブランチをリモートにpushし、qaブランチへのマージリクエスト(GitLab)／プルリクエスト(GitHub)を作成してください。pushしたブランチは削除しないこと。
allowed-tools: Bash
---

# 現在のブランチからqaへのマージリクエスト / プルリクエスト作成

現在の作業ブランチを `origin` にpushし、そのブランチから `qa` ブランチへの
マージリクエスト（GitLab）またはプルリクエスト（GitHub）を作成してください。

**重要**: pushしたソースブランチは削除しないこと。QA確認後に develop などへ進めるため、
ブランチを残す。GitLab では `glab mr merge` に `--remove-source-branch` を、
GitHub では `gh pr merge` に `--delete-branch` を**付けない**こと。

## 対象プラットフォーム

セッション冒頭に注入される `<repo-hosting>` の判定結果に従い、**該当プラットフォームの
手順だけ**を実行する（判定のやり直しは不要）。`<repo-hosting>` が無いセッションでのみ
`git remote get-url origin` のホスト名から判定する。

## タイトル形式

`qa YYYYMMDD HH:MM` 形式で現在時刻を使用する（例: `qa 20260311 14:30`）

## 説明文

qaブランチと現在のブランチの差分に含まれるすべての変更を機能単位でリストアップして記載する。
直近の修正だけでなく、qaに未マージのすべての差分を対象とすること。

## 手順（共通）

1. `git branch --show-current` で現在のブランチ名を取得する
2. 現在のブランチを `origin` にpushする: `git push -u origin "$(git branch --show-current)"`
3. 現在時刻をJSTで取得してタイトルを生成する: `TZ=Asia/Tokyo date '+%Y%m%d %H:%M'`
4. `git log --oneline origin/qa..HEAD` でqaと現在のブランチの差分コミット一覧を取得
5. 差分コミットの内容から機能・修正をリストアップして説明文を生成する

## 作成コマンド

### GitLab の場合

1. マージリクエストを作成する:
   ```
   glab mr create \
     --source-branch "$(git branch --show-current)" \
     --target-branch qa \
     --title "qa $(TZ=Asia/Tokyo date '+%Y%m%d %H:%M')" \
     --description "<生成した説明文>" \
     --yes
   ```
2. 作成されたMRのID（URLの末尾の数字）を取得する
3. 5秒待つ: `sleep 5`
4. auto-mergeを有効にする（**`--remove-source-branch` は付けない**＝ソースブランチを残す）:
   ```
   glab mr merge <MR_ID> --auto-merge --yes
   ```

### GitHub の場合

1. プルリクエストを作成する:
   ```
   gh pr create \
     --base qa \
     --head "$(git branch --show-current)" \
     --title "qa $(TZ=Asia/Tokyo date '+%Y%m%d %H:%M')" \
     --body "<生成した説明文>"
   ```
2. 作成されたPRの番号（URLの末尾の数字）を取得する
3. 5秒待つ: `sleep 5`
4. auto-mergeを有効にする（**`--delete-branch` は付けない**＝ソースブランチを残す）:
   ```
   gh pr merge <PR番号> --auto --merge
   ```
   リポジトリ設定でauto-mergeが無効な場合はこのコマンドが失敗する。その場合は
   マージせず、「auto-merge未有効のため手動マージが必要」と報告する。

## 完了時

作成されたマージリクエスト / プルリクエストのURLを出力する。
