---
name: cleanup-merged
description: リモートのdevelopブランチにマージ済みのローカルブランチを一覧表示し、確認後に一括削除する
allowed-tools: Bash, AskUserQuestion
---

# マージ済みローカルブランチの一括削除

リモートのdevelopブランチにマージ済みのローカルブランチを一括削除します。

## 手順

1. `git cleanup-merged --dry-run` で削除対象ブランチを一覧表示する
2. 削除対象がある場合、AskUserQuestion で削除を確認する
3. ユーザーが承認したら `git cleanup-merged` を実行する
4. 削除したブランチ数と一覧を報告する

## 除外対象

- main / master / develop / staging ブランチ
- 現在チェックアウト中のブランチ（`*` マーク付き）

## ベースブランチの変更

デフォルトは `develop`。別ブランチを基準にしたい場合は引数で渡す:
```
git cleanup-merged main
```
