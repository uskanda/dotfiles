uskanda's dotfiles
============================

作業中

このディレクトリ全体はChezmoi管理下である。
Chezmoiのネーミングルールに反するものは無視されるのでセットアップスクリプトなどもここにそのまま置く。

WSL2(Ubuntu)/Ubuntu/MacOSは

installation
-----------------------------
### Windows
* Powershellを管理者権限で実行

> Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
> ./setup.ps1ss

リニューアル点
-----------------------------
* fishをやめてzshベースで再検討
* dotfiles管理をhomeshickからchezmoiへ移行

ToDo
-----------------------------
* Terminal Multiplexer選定 Zellijってなんぞや
* ターミナルエミュレータ選定 Alacrittyかなあ
* シェル zsh出戻り
* モダンなzshをさぐる まだohmyzshやpreztoとかなのか
* シェル関連 Starship
* 他Rustベースプロダクト
