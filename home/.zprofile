#
# Executes commands at login pre-zshrc.
#
# Authors:
#   Sorin Ionescu <sorin.ionescu@gmail.com>
#

#
# Browser
#

if [[ "$OSTYPE" == darwin* ]]; then
  export BROWSER='open'
fi

#
# Editors
#

export EDITOR='vim'
export VISUAL='vim'
export PAGER='less'

#
# Language
#

if [[ -z "$LANG" ]]; then
  export LANG='en_US.UTF-8'
fi

#
# Paths
#

# Ensure path arrays do not contain duplicates.
typeset -gU cdpath fpath mailpath path

# Set the the list of directories that cd searches.
# cdpath=(
#   $cdpath
# )

# Set the list of directories that Zsh searches for programs.
# TODO: PythonPathは必要な時のみ読み込む
path=(
  /usr/local/{bin,sbin}
  ~/Library/Python/2.7/bin
  $path
)

#
# Less
#

# Set the default Less options.
# Mouse-wheel scrolling has been disabled by -X (disable screen clearing).
# Remove -X and -F (exit if the content fits on one screen) to enable it.
export LESS='-F -g -i -M -R -S -w -X -z-4'

# Set the Less input preprocessor.
# Try both `lesspipe` and `lesspipe.sh` as either might exist on a system.
if (( $#commands[(i)lesspipe(|.sh)] )); then
  export LESSOPEN="| /usr/bin/env $commands[(i)lesspipe(|.sh)] %s 2>&-"
fi

#
# Temporary Files
#

if [[ ! -d "$TMPDIR" ]]; then
  export TMPDIR="/tmp/$LOGNAME"
  mkdir -p -m 700 "$TMPDIR"
fi

TMPPREFIX="${TMPDIR%/}/zsh"

#
# Options
#
setopt IGNOREEOF

#
# Alias
#
alias l='ls'
alias la="ls -a"
alias lf="ls -F"
alias ll="ls -l"
alias lal="ls -Al"
alias ltr="ls -ltr"
alias laltr="ls -altr"

alias f="tail -f"
alias F="tail -F"
alias h="head -n 30"
alias t="tail -n 30"
alias g="git"
alias gi="git"
alias where="command -v"
alias du="du -h"
alias df="df -h"
alias su="su -l"
alias rmdir='rm -rf'
alias psa='ps aux'
alias p=$PAGER
alias agp='ag --pager="less -R"'

#OS Specific
case $OSTYPE in
  linux*)
    alias ls='ls --color'
    ;;
  darwin*)
    alias ls='ls -G'
    alias v='mvim'
    alias mvim='mvim --remote-tab-silent'
    alias o='open'
    alias oa='open -a'
    alias vlc="open -a VLC"
    alias pv="open -a Preview"
    alias preview="open -a Preview"
    alias keynote="open -a Keynote"
    alias pf="open -a \"Path Finder\""
    alias tac="gtac"
    alias -s gif=preview
    alias -s jpg=preview
    alias -s jpeg=preview
    alias -s png=preview
    alias -s bmp=preview
    alias -s pdf=preview
    ;;
esac

#for Typo
alias dc='cd'
alias bc='cd'
alias les='less'

# Global alias
alias -g L='| lv'
alias -g P='| $PAGER'
alias -g H='| head -n 30'
alias -g Hn='| head -n'
alias -g T='| tail -n 30'
alias -g Tn='| tail -n'
alias -g G='| grep'
alias -g Ge='| grep -e'
alias -g Gv='| grep -v'
alias -g W='| wc'
alias -g S='| sed'
alias -g A='| awk'
alias -g B=';echo "\a"'
alias -g F='| tail -f'
alias -g X='| xargs'


#
# Powerline
#
if type powerline >/dev/null 2>&1; then
  powerline-daemon -q
  . ~/.zsh/scripts/powerline.zsh
else
  autoload colors
  colors
    PROMPT="%{${fg[green]}%}%/%%%{${reset_color}%} "
    PROMPT2="%{${fg[red]}%}%_%%%{${reset_color}%} "
  #  RPROMPT="[%n@%m]"
    SPROMPT="%{${fg[red]}%}%r is correct? [n,y,a,e]:%{${reset_color}%} "
    [ -n "${REMOTEHOST}${SSH_CONNECTION}" ] &&
      PROMPT="%{${fg[white]}%}${HOST%%.*} ${PROMPT}"
fi

# anyenv
if [ -d ${HOME}/.anyenv ] ; then
    export PATH="$HOME/.anyenv/bin:$PATH"
        eval "$(anyenv init -)"
	    for D in `ls $HOME/.anyenv/envs`
        do
        export PATH="$HOME/.anyenv/envs/$D/shims:$PATH"
    done
fi
