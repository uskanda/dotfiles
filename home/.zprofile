#LIGHTWEIGHT_MODE=false
LIGHTWEIGHT_MODE=true

export TERM='xterm-256color'

#
#
# Editors
#
export EDITOR='vim'
export VISUAL='vim'
export PAGER='less'

#
# Temporary Files
#
if [[ ! -d "$TMPDIR" ]]; then
  export TMPDIR="/tmp/$LOGNAME"
  mkdir -p -m 700 "$TMPDIR"
fi
TMPPREFIX="${TMPDIR%/}/zsh"

# Alias
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
    alias preview="open -a Preview"
    alias keynote="open -a Keynote"
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

#History Settings
HISTFILE="${ZDOTDIR:-$HOME}/.zhistory"       # The path to the history file.
HISTSIZE=30000  
SAVEHIST=30000 
setopt BANG_HIST
setopt EXTENDED_HISTORY
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_FIND_NO_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_SAVE_NO_DUPS
setopt HIST_VERIFY
setopt HIST_BEEP

#Directory Settings
setopt AUTO_CD
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS 
setopt PUSHD_SILENT
setopt PUSHD_TO_HOME
setopt CDABLE_VARS
setopt AUTO_NAME_DIRS
setopt MULTIOS
setopt EXTENDED_GLOB
