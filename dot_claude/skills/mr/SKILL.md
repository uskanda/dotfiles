---
name: mr
description: マージリクエスト用にこのブランチの修正内容を日本語テキストにまとめ、GitLab CLIでマージリクエストを作成してください。
allowed-tools: Bash, Read, Grep, Glob
---

# マージリクエストの作成

マージリクエスト用にこのブランチの修正内容を日本語テキストにまとめ、GitLab CLIでマージリクエストを作成してください。

## 出力形式

- タイトル: 1行
- 説明文: 10行以内の箇条書きで、markdownのリスト形式で1行を書くこと。

## ルール

1. ブランチ名が `feature/{number}-{feature-title}` という形式の場合、タイトルの先頭に `#{number}` をつける。ブランチの中に含まれるコミットのコミットメッセージに#{number}というprefixがある場合も、タイトルの先頭に `#{number}`をつける。複数存在する場合は、numberの数字が若い順にソートする。
2. developブランチからの差分コミットを確認して内容をまとめる
3. 変更の目的と主要な修正点を簡潔に説明する

## 手順

1. `git branch --show-current` で現在のブランチ名を確認
2. `git log --oneline develop..HEAD` でコミット一覧を確認
3. ブランチ名からissue番号を抽出（該当する場合）
4. タイトルと説明文を生成して出力
5. 生成したタイトルと説明文を使って、以下のコマンドでマージリクエストを作成する:
   ```
   glab mr create \
     --target-branch develop \
     --title "<生成したタイトル>" \
     --description "<生成した説明文>" \
     --yes
   ```
6. 作成されたマージリクエストのURLを出力する
