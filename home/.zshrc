#zmodload zsh/zprof && zprof

# Install zplug if not exist
if [[ ! -d ~/.zplug ]];then
    git clone https://github.com/b4b4r07/zplug ~/.zplug
fi
source ~/.zplug/init.zsh

zplug "b4b4r07/enhancd", use:init.sh
zplug "b4b4r07/peco-tmux.sh", as:command, use:'(*).sh', rename-to:'$1'
zplug "bhilburn/powerlevel9k", use:powerlevel9k.zsh-theme
zplug "zsh-users/zsh-syntax-highlighting", defer:2


zstyle ':completion:*' group-name ''
zstyle ':completion:*' completer _expand _oldlist _complete _match _prefix _approximate _list _history
zstyle ':completion:*:warnings' format $RED'No matches for:'$YELLOW' %d'$DEFAULT
zstyle ':completion:*:descriptions' format $YELLOW'completing %B%d%b'$DEFAULT
zstyle ':completion:*:corrections' format $YELLOW'%B%d '$RED'(errors: %e)%b'$DEFAULT
zstyle ':completion:*:options' description 'yes'
if [ -f ~/.zsh/auto-fu.zsh ]; then
    source ~/.zsh/auto-fu.zsh
    zle-line-init () {auto-fu-init;}; zle -N zle-line-init
fi

# Install zplug plugins
if ! zplug check --verbose; then
	printf "Install zplug plugins? [y/N]: "
	if read -q; then
		echo; zplug install
	fi
fi
zplug load

ENHANCD_FILTER="peco-tmux"
POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(dir vcs)
POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(status root_indicator background_jobs history)

#
# cdd
#
if [ -f ~/.zsh/cdd/cdd ]; then
    source ~/.zsh/cdd/cdd
    typeset -ga chpwd_functions
    chpwd_functions+=_cdd_chpwd
fi

#
# chpwd and enter 
# http://qiita.com/yuyuchu3333/items/e9af05670c95e2cc5b4d
# http://qiita.com/yuyuchu3333/items/b10542db482c3ac8b059
#
function do_enter() {
    if [ -n "$BUFFER" ]; then
        zle accept-line
        return 0
    fi
    echo
    ls_abbrev_with_git
    zle reset-prompt
    return 0
}
zle -N do_enter
bindkey '^M' do_enter
if [ -f ~/.zsh/auto-fu.zsh ]; then
bindkey -M afu '^M' do_enter
fi

chpwd() {
    ls_abbrev_with_git
    if [[ -n "$TMUX_PANE" ]];then
      tmux set-window-option window-status-format " #I ${PWD:t} " > /dev/null
    fi
}
ls_abbrev_with_git() {
    if [[ ! -r $PWD ]]; then
        return
    fi
    # -a : Do not ignore entries starting with ..
    # -C : Force multi-column output.
    # -F : Append indicator (one of */=>@|) to entries.
    local cmd_ls='ls'
    local -a opt_ls
    opt_ls=('-aCF' '--color=always')
    case "${OSTYPE}" in
        freebsd*|darwin*)
            if type gls > /dev/null 2>&1; then
                cmd_ls='gls'
            else
                # -G : Enable colorized output.
                opt_ls=('-aCFG')
            fi
            ;;
    esac

    local ls_result
    ls_result=$(CLICOLOR_FORCE=1 COLUMNS=$COLUMNS command $cmd_ls ${opt_ls[@]} | sed $'/^\e\[[0-9;]*m$/d')

    local ls_lines=$(echo "$ls_result" | wc -l | tr -d ' ')

    if [ $ls_lines -gt 10 ]; then
        echo "$ls_result" | head -n 5
        echo '...'
        echo "$ls_result" | tail -n 5
        echo "$(command ls -1 -A | wc -l | tr -d ' ') files exist"
    else
        echo "$ls_result"
    fi

    if [ "$(git rev-parse --is-inside-work-tree 2> /dev/null)" = 'true' ]; then
        echo
        echo -e "\e[0;33m--- git status ---\e[0m"
        unbuffer git status -sb | head -n 1
        unbuffer git status -s | git column
        git --no-pager log -5 --oneline --decorate
    fi
}

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

if (which zprof > /dev/null) ;then
#  zprof | less
fi
