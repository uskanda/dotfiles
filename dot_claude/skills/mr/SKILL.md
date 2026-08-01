---
name: mr
description: このブランチの修正内容を日本語テキストにまとめ、develop 向けのマージリクエスト(GitLab)／プルリクエスト(GitHub)を作成してください。
allowed-tools: Bash, Read, Grep, Glob
---

# マージリクエスト / プルリクエストの作成

このブランチの修正内容を日本語テキストにまとめ、`develop` ブランチ向けの
マージリクエスト（GitLab）またはプルリクエスト（GitHub）を作成してください。

## 対象プラットフォーム

セッション冒頭に注入される `<repo-hosting>` の判定結果に従い、**該当プラットフォームの
手順だけ**を実行する（判定のやり直しは不要）。

`<repo-hosting>` が無いセッションでのみ、`git remote get-url origin` のホスト名から
判定する（`github.com`／`*github*` → GitHub、`gitlab.com`／`*gitlab*` → GitLab、
それ以外は `.github/workflows/` と `.gitlab-ci.yml` の有無で判断）。

## 出力形式

- タイトル: 1行
- 説明文: 10行以内の箇条書きで、markdownのリスト形式で1行を書くこと。

## ルール

1. ブランチ名が `feature/{number}-{feature-title}` という形式の場合、タイトルの先頭に `#{number}` をつける。ブランチの中に含まれるコミットのコミットメッセージに#{number}というprefixがある場合も、タイトルの先頭に `#{number}`をつける。複数存在する場合は、numberの数字が若い順にソートする。
2. developブランチからの差分コミットを確認して内容をまとめる
3. 変更の目的と主要な修正点を簡潔に説明する

## 手順（共通）

1. `git branch --show-current` で現在のブランチ名を確認
2. `git log --oneline develop..HEAD` でコミット一覧を確認
3. ブランチ名からissue番号を抽出（該当する場合）
4. タイトルと説明文を生成して出力

## 作成コマンド

### GitLab の場合

```
glab mr create \
  --target-branch develop \
  --title "<生成したタイトル>" \
  --description "<生成した説明文>" \
  --yes
```

### GitHub の場合

`gh pr create` はリモートに存在するブランチが必要なため、未pushなら先にpushする:

```
git push -u origin HEAD
gh pr create \
  --base develop \
  --head "$(git branch --show-current)" \
  --title "<生成したタイトル>" \
  --body "<生成した説明文>"
```

既に同じブランチのPRが存在してコマンドが失敗した場合は、新規作成せず
`gh pr view --json url -q .url` で既存PRのURLを報告する。

## 完了時

作成されたマージリクエスト / プルリクエストのURLを出力する。
