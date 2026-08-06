---
name: mr
description: マージリクエスト用にこのブランチの修正内容を日本語テキストにまとめ、GitLab CLIでマージリクエストを作成し、auto-mergeを有効化してください。
allowed-tools: Bash, Read, Grep, Glob
---

# マージリクエストの作成

マージリクエスト用にこのブランチの修正内容を日本語テキストにまとめ、GitLab CLIでマージリクエストを作成し、auto-merge（CI通過後に自動マージ）を有効化してください。

## 出力形式

- タイトル: 1行
- 説明文: 10行以内の箇条書きで、markdownのリスト形式で1行を書くこと。

## ルール

1. ブランチ名が `feature/{number}-{feature-title}` という形式の場合、タイトルの先頭に `#{number}` をつける。ブランチの中に含まれるコミットのコミットメッセージに#{number}というprefixがある場合も、タイトルの先頭に `#{number}`をつける。複数存在する場合は、numberの数字が若い順にソートする。
2. developブランチからの差分コミットを確認して内容をまとめる
3. 変更の目的と主要な修正点を簡潔に説明する
4. デフォルトで auto-merge（CI＝全マージチェック通過後に自動マージ）を有効にする

## 手順

1. `git branch --show-current` で現在のブランチ名を確認
2. `git log --oneline develop..HEAD` でコミット一覧を確認
3. ブランチ名からissue番号を抽出（該当する場合）
4. タイトルと説明文を生成して出力
5. 生成したタイトルと説明文を使って、以下のコマンドでマージリクエストを作成する（`glab mr create` には auto-merge フラグが無いため、作成と auto-merge は分ける）:
   ```
   glab mr create \
     --target-branch develop \
     --title "<生成したタイトル>" \
     --description "<生成した説明文>" \
     --yes
   ```
6. 作成されたMRのID（URL末尾の数字）を取得する
7. 5秒待つ（作成直後はGitLab側のマージ可否計算が未完了で一時的に `cannot_be_merged` になることがあるため）: `sleep 5`
8. auto-merge を有効化する（CI＝全マージチェック通過後に自動マージ）:
   ```
   glab mr merge <MR_ID> --auto-merge --yes
   ```
9. 作成されたマージリクエストのURLを出力する
