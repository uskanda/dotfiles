---
name: merge-develop
description: developのリモートの変更をpullした後、今いるブランチにその変更をマージしてください。まずfast-forwardを試み、不能なら自動で --no-ff マージします。
allowed-tools: Bash
---

# developの変更を現在のブランチにマージ

developのリモートの変更をpullした後、今いるブランチにその変更をマージしてください。まず fast-forward を試み、fast-forward できない場合は**ユーザーに確認せず自動で `--no-ff` マージ**を実行します（リベースはしません）。

## 手順

1. **未コミットの変更を確認**
   - `git status` で未コミットの変更があるか確認
   - 未コミットの変更がある場合は**警告して処理を中止**

2. **リモートのdevelopをfetch**
   - `git fetch origin develop` でリモートの最新状態を取得

3. **fast-forwardマージを試みる**
   - `git merge --ff-only origin/develop` を実行
   - 成功した場合はそのまま完了（「fast-forwardでマージしました」と報告）

4. **fast-forwardが不可能な場合（`--ff-only` が失敗した場合）**
   - **ユーザーに確認せず、そのまま** `git merge --no-ff origin/develop` を実行する
   - `AskUserQuestion` で通常マージかリベースかを聞かないこと。リベースもしないこと
   - マージコミットが作られた旨を報告する
   - コンフリクトが発生した場合は、マージを中断したままコンフリクトしたファイル一覧を提示してユーザーに知らせる（勝手に `git merge --abort` はしない）

5. **結果確認**
   - `git log --oneline -5` で最新のコミットを表示
   - fast-forward だったか `--no-ff` マージだったかを明示して報告する

## 未コミットの変更がある場合

以下のように警告して、何も実行しないこと：

```
未コミットの変更があります。

変更されたファイル:
- [ファイル一覧]

先にコミットするか、stashしてから再度実行してください。
処理を中止しました。
```
