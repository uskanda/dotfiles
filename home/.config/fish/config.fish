# install fisherman if fisher command is missing
if not type -q fisher
  echo "fisherman does not exist. install now."
  curl -s -Lo ~/.config/fish/functions/fisher.fish --create-dirs https://git.io/fisher
  fish -c "fisher"
end

set -U FZF_TMUX 1
set -U fish_prompt_pwd_dir_length 4

source ~/.config/fish/config_local.fish

abbr l 'ls'
abbr la "ls -a"
abbr lf "ls -F"
abbr ll "ls -l"
abbr lal "ls -Al"
abbr ltr "ls -ltr"
abbr laltr "ls -altr"
abbr f "tail -f"
abbr F "tail -F"
abbr h "head -n 30"
abbr t "tail -n 30"
abbr g "git"
abbr gi "git"
abbr where "command -v"
abbr du "du -h"
abbr df "df -h"
abbr su "su -l"

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


#不服だがfunctions/completionsはfishermanにくれてやる
