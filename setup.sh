cd $HOME
sh -c "$(curl -fsLS get.chezmoi.io/lb)"

cd $HOME/dotfiles
chezmoi init --source="$HOME/dotfiles" --apply