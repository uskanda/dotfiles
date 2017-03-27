#zmodload zsh/zprof && zprof

if $LIGHTWEIGHT_MODE; then
  echo -e "\e[33m-----Run zsh as lightweight mode-----\e[m"
  autoload -Uz colors
  colors
  PROMPT="%F{green}[%d]%k "
  return 
fi

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



if (which zprof > /dev/null) ;then
#  zprof | less
fi
