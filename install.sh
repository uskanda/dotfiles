
for xenv in rbenv ndenv pyenv
do
  if [ `anyenv envs | grep -c $xenv` -eq 0 ]; then
    echo "$xenv does not exist. start installing..."
    anyenv install $xenv
  else
    echo "$xenv already exists. skip install."
  fi
done

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
  ln -s ~/.homesick/repos/unix-rc/home/.zsh/zsh-completions/src/_$command ~/.homesick/repos/unix-rc/home/.zsh/zsh-completions-selected/
done
