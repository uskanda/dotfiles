uskanda's dotfiles
============================

作業中

このディレクトリ全体はChezmoi管理下である。
Chezmoiのネーミングルールに反するものは無視されるのでセットアップスクリプトなどもここにそのまま置く。

WSL2(Ubuntu)/Ubuntu/MacOS対応予定。

installation
-----------------------------
### Windows
* Powershellを管理者権限で実行

> Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
> ./setup.ps1

### Ubuntu, WSL

```bash
./setup
```

リニューアル点
-----------------------------
* fishをやめてzshベースで再構成
* dotfiles管理をhomeshickからchezmoiへ移行

ToDo
-----------------------------
* xcode-select --installの追加
* Terminal Multiplexer選定 Zellij、prefix連打でペイン動くのできないっぽい？
* ターミナルエミュレータ選定 Alacritty or Wezterm Wezterm寄り
* Starshipプロンプトブラッシュアップ
* 他Rustベースプロダクト
* atuin違うかもな... fzfベースも考える
* zoxide or z
* bat
* delta new git diff
* brewfileの追加
* aptは...まあええか？
* wezterm muxまわり設定
* im-select VSCode vi mode IME設定

学び
-----------------------------
* chezmoiってsymlinkでなくてコピーなのね
* コピー先ファイルの変更はchezmoi addで再反映する

このdotfiles/setupで対象にしないこと
-----------------------------
* Nerd Fonts適用のフォントのビルド・インストール
  現在はUDEV Gothicを使っており、Nerd Fonts適用のUDEV Gothicを使う前提
* アプリケーション側で同期設定のあるアプリ
  * VSCode

やったけど未反映
---------------------
brew tap daipeihust/tap
brew install im-select
