# install fisherman if fisher command is missing
if not type -q fisher
  echo "fisherman does not exist. install now."
  curl -s -Lo ~/.config/fish/functions/fisher.fish --create-dirs https://git.io/fisher
  fish -c "fisher"
end

set -U fish_prompt_pwd_dir_length 4
source ~/.config/fish/config_local.fish

set -U FZF_TMUX 1

function do_enter
  set -l query (commandline)

  if test -n $query
    echo
    eval $query
    commandline ''
  else
    echo
    ls
    if test (git rev-parse --is-inside-work-tree 2> /dev/null)
      echo -e "\e[0;33m--- git status ---\e[0m"
      git status -sb
      git --no-pager log -5 --oneline --decorate
    end
  end
  commandline -f repaint
end

function fish_user_key_bindings
  bind \cm do_enter
end

#不服だがfunctions/completionsはfishermanにくれてやる
