$src = "$env:USERPROFILE\dotfiles\.config\alacritty.toml"

$dstDir = "$env:APPDATA\alacritty"
$dst = "$dstDir\alacritty.toml"

# ディレクトリが無ければ作成
if (!(Test-Path $dstDir)) {
    New-Item -ItemType Directory -Path $dstDir | Out-Null
}

# 既存リンクやファイルがあれば削除
if (Test-Path $dst) {
    Remove-Item $dst
}

# シンボリックリンクを作成（管理者権限必須）
New-Item -ItemType SymbolicLink -Path $dst -Target $src
