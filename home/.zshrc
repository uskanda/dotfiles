#
# Executes commands at the start of an interactive session.
#
# Authors:
#   Sorin Ionescu <sorin.ionescu@gmail.com>
#

# Source Prezto.
if [[ -s "${ZDOTDIR:-$HOME}/.zprezto/init.zsh" ]]; then
  source "${ZDOTDIR:-$HOME}/.zprezto/init.zsh"
fi

# fzf
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# enhancd
if [ -f "/Users/uskanda/.enhancd/zsh/enhancd.zsh" ]; then
    source "/Users/uskanda/.enhancd/zsh/enhancd.zsh"
    export ENHANCD_FILTER="fzf-tmux"
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
        git status -sb
    fi
}

# zprof
#if (which zprof > /dev/null) ;then
#  zprof | less
#fi
