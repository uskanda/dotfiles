---
name: merge_develop
description: developのリモートの変更をpullした後、今いるブランチにその変更をマージしてください。可能であればfast-forwardでマージしてください。
allowed-tools: Bash, AskUserQuestion
---

# developの変更を現在のブランチにマージ

developのリモートの変更をpullした後、今いるブランチにその変更をマージしてください。可能であればfast-forwardでマージしてください。

## 手順

1. **未コミットの変更を確認**
   - `git status` で未コミットの変更があるか確認
   - 未コミットの変更がある場合は**警告して処理を中止**

2. **リモートのdevelopをfetch**
   - `git fetch origin develop` でリモートの最新状態を取得

3. **fast-forwardマージを試みる**
   - `git merge --ff-only origin/develop` を実行
   - 成功した場合はそのまま完了

4. **fast-forwardが不可能な場合**
   - ユーザーに通常マージかリベースかを `AskUserQuestion` ツールで確認
   - 「通常マージ (--no-ff)」を選んだ場合: `git merge --no-ff origin/develop` を実行
   - 「リベース」を選んだ場合: `git rebase origin/develop` を実行

5. **結果確認**
   - `git log --oneline -5` で最新のコミットを表示

## 未コミットの変更がある場合

以下のように警告して、何も実行しないこと：

```
未コミットの変更があります。

変更されたファイル:
- [ファイル一覧]

先にコミットするか、stashしてから再度実行してください。
処理を中止しました。
```
