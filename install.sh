anyenv install rbenv
anyenv install ndenv
anyenv install pyenv

# Bundler
# RubyGems Manager
if which bundle > /dev/null; then
    echo Bundler exists. Skip install.
else
    gem install bundler
fi

# diff-highlight
# Installed by git, make symbolic link to PATHed dir
ln -s /usr/local/opt/git/share/git-core/contrib/diff-highlight/diff-highlight /usr/local/bin/

for command in adb ag android brew bundle cap coffee git-flow jq knife middleman nvm node rails tmuxinator vagrant
do
  ln -s ~/.homesick/repos/unix-rc/home/.zsh/zsh-completions/src/_$command ~/.homesick/repos/unix-rc/home/.zsh/zsh-completions-selected/
done
