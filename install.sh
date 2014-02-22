homesick_unix_repo=$HOME/.homesick/repos/unix-rc/
cd $homesick_unix_repo

if [ ! -L $homesick_unix_repo/home/.anyenv/plugins ]; then
  echo "setting up anyenv plugins..."
  ln -s $homesick_unix_repo/anyenv-plugins/ $homesick_unix_repo/home/.anyenv/plugins
else
  echo "anyenv plugins are already symlinked"
fi

for xenv in rbenv ndenv pyenv
do
  if [ `anyenv envs | grep -c $xenv` -eq 0 ]; then
    echo "$xenv does not exist. start installing..."
    anyenv install $xenv
  else
    echo "$xenv already exists. skip install."
  fi
done

source ~/.zshrc

rbenv install 2.1.0-dev
pyenv install 2.7.5
pip install --allow-external percol --allow-unverified percol percol

# Bundler
# RubyGems Manager
if which bundle > /dev/null; then
    echo bundler already exists. skip install.
else
    gem install bundler
fi

# diff-highlight
# Installed by git, make symbolic link to PATHed dir
if which diff-highlight > /dev/null; then
  echo diff-highlight already exists. skip install.
else
  ln -s /usr/local/opt/git/share/git-core/contrib/diff-highlight/diff-highlight /usr/local/bin/
fi

for command in adb ag android brew bundle cap coffee git-flow jq knife middleman nvm node rails tmuxinator vagrant
do
  if [ -L ~/.homesick/repos/unix-rc/home/.zsh/zsh-completions/src/_$command ]; then
    ln -s ~/.homesick/repos/unix-rc/home/.zsh/zsh-completions/src/_$command ~/.homesick/repos/unix-rc/home/.zsh/zsh-completions-selected/
  fi
done
