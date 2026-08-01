---
name: mr-staging
description: developブランチからstagingブランチへのマージリクエスト(GitLab)／プルリクエスト(GitHub)を作成してください。
allowed-tools: Bash
---

# developからstagingへのマージリクエスト / プルリクエスト作成

`develop` ブランチから `staging` ブランチへのマージリクエスト（GitLab）または
プルリクエスト（GitHub）を作成してください。

## 対象プラットフォーム

セッション冒頭に注入される `<repo-hosting>` の判定結果に従い、**該当プラットフォームの
手順だけ**を実行する（判定のやり直しは不要）。`<repo-hosting>` が無いセッションでのみ
`git remote get-url origin` のホスト名から判定する。

## タイトル形式

`staging YYYYMMDD HH:MM` 形式で現在時刻を使用する（例: `staging 20260311 14:30`）

## 説明文

developとstagingの差分に含まれるすべての変更を機能単位でリストアップして記載する。
直近の修正だけでなく、stagingに未マージのすべての差分を対象とすること。

## 手順（共通）

1. 現在時刻をJSTで取得してタイトルを生成する: `TZ=Asia/Tokyo date '+%Y%m%d %H:%M'`
2. `git log --oneline origin/staging..origin/develop` でdevelopとstagingの差分コミット一覧を取得
3. 差分コミットの内容から機能・修正をリストアップして説明文を生成する

## 作成コマンド

### GitLab の場合

1. マージリクエストを作成する:
   ```
   glab mr create \
     --source-branch develop \
     --target-branch staging \
     --title "staging $(TZ=Asia/Tokyo date '+%Y%m%d %H:%M')" \
     --description "<生成した説明文>" \
     --yes
   ```
2. 作成されたMRのID（URLの末尾の数字）を取得する
3. 5秒待つ: `sleep 5`
4. auto-mergeを有効にする:
   ```
   glab mr merge <MR_ID> --auto-merge --yes
   ```

### GitHub の場合

1. プルリクエストを作成する:
   ```
   gh pr create \
     --base staging \
     --head develop \
     --title "staging $(TZ=Asia/Tokyo date '+%Y%m%d %H:%M')" \
     --body "<生成した説明文>"
   ```
2. 作成されたPRの番号（URLの末尾の数字）を取得する
3. 5秒待つ: `sleep 5`
4. auto-mergeを有効にする:
   ```
   gh pr merge <PR番号> --auto --merge
   ```
   リポジトリ設定でauto-mergeが無効な場合はこのコマンドが失敗する。その場合は
   マージせず、「auto-merge未有効のため手動マージが必要」と報告する。

## 完了時

作成されたマージリクエスト / プルリクエストのURLを出力する。
