---
name: mr-main
description: developブランチからmainブランチへのマージリクエストをGitLab CLIで作成してください。
allowed-tools: Bash
---

# developからmainへのマージリクエスト作成

developブランチからmainブランチへのマージリクエストをGitLab CLIで作成してください。

## タイトル形式

`main YYYYMMDD HH:MM` 形式で現在時刻を使用する（例: `main 20260311 14:30`）

## 説明文

developとmainの差分に含まれるすべての変更を機能単位でリストアップして記載する。
直近の修正だけでなく、mainに未マージのすべての差分を対象とすること。

## 手順

1. 現在時刻をJSTで取得してタイトルを生成する: `TZ=Asia/Tokyo date '+%Y%m%d %H:%M'`
2. `git log --oneline origin/main..origin/develop` でdevelopとmainの差分コミット一覧を取得
3. 差分コミットの内容から機能・修正をリストアップして説明文を生成する
4. 以下のコマンドでマージリクエストを作成する:
   ```
   glab mr create \
     --source-branch develop \
     --target-branch main \
     --title "main $(TZ=Asia/Tokyo date '+%Y%m%d %H:%M')" \
     --description "<生成した説明文>" \
     --yes
   ```
5. 作成されたMRのID（URLの末尾の数字）を取得する
6. 5秒待つ: `sleep 5`
7. auto-mergeを有効にする:
   ```
   glab mr merge <MR_ID> --auto-merge --yes
   ```
8. 作成されたマージリクエストのURLを出力する
