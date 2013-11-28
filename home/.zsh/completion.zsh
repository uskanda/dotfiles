# https://raw.github.com/tarao/dotfiles/master/.zsh/completion.zsh
# completion
setopt   auto_list auto_param_slash list_packed rec_exact
unsetopt list_beep
zstyle ':completion:*' menu select
zstyle ':completion:*' list-colors 'di=1;34'
zstyle ':completion:*' format '%F{white}%d%f'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':completion:*' keep-prefix
zstyle ':completion:*' remote-access false
zstyle ':completion:*' completer _oldlist _complete _match _ignored \
    _list _history
zstyle ':completion:sudo:*' environ PATH="$SUDO_PATH:$PATH"
autoload -U compinit
compinit

function () { # precompile
    local A
    A=~/.zsh/auto-fu.zsh
    [[ -e "${A:r}.zwc" ]] && [[ "$A" -ot "${A:r}.zwc" ]] ||
    zsh -c "source $A; auto-fu-zcompile $A ${A:h}" >/dev/null 2>&1
}
source ~/.zsh/auto-fu

function install-auto-fu () {
    auto-fu-install

    zstyle ':auto-fu:highlight' input bold
    zstyle ':auto-fu:highlight' completion fg=white,dim
    zstyle ':auto-fu:highlight' completion/one fg=blue,dim
    zstyle ':auto-fu:var' postdisplay ''
    zstyle ':auto-fu:var' track-keymap-skip opp

    function zle-line-init () { auto-fu-init }; zle -N zle-line-init
    # zle -N zle-keymap-select auto-fu-zle-keymap-select

    function afu+cancel () {
        afu-clearing-maybe
        ((afu_in_p == 1)) && { afu_in_p=0; BUFFER="$buffer_cur"; }
    }
    zle -N afu+cancel
    function bindkey-advice-before () {
        local key="$1"
        local advice="$2"
        local widget="$3"
        [[ -z "$widget" ]] && {
            local -a bind
            bind=(`bindkey -M main "$key"`)
            widget=$bind[2]
        }
        local fun="$advice"
        if [[ "$widget" != "undefined-key" ]]; then
            local code=${"$(<=(cat <<"EOT"
                function $advice-$widget () {
                    zle $advice
                    zle $widget
                }
                fun="$advice-$widget"
EOT
            ))"}
            eval "${${${code//\$widget/$widget}//\$key/$key}//\$advice/$advice}"
        fi
        zle -N "$fun"
        bindkey -M afu "$key" "$fun"
    }
    bindkey-advice-before "^G" afu+cancel
    bindkey-advice-before "^[" afu+cancel

    function afu+accept-line-or-do-enter() {
    if [ -n "$BUFFER" ]; then
        zle afu+accept-line
        return 0
    fi
    echo
    ls
    # ls_abbrev
    if [ "$(git rev-parse --is-inside-work-tree 2> /dev/null)" = 'true' ]; then
        echo
        echo -e "\e[0;33m--- git status ---\e[0m"
        git status -sb
    fi
    zle reset-prompt
    return 0
    }
    zle -N afu+accept-line-or-do-enter
    bindkey -M afu "^M" afu+accept-line-or-do-enter
    bindkey -M afu "^J" afu+accept-line-or-do-enter
    bindkey-advice-before "^J" afu+cancel afu+accept-line-or-do-enter

    # delete unambiguous prefix when accepting line
    function afu+delete-unambiguous-prefix () {
        afu-clearing-maybe
        local buf; buf="$BUFFER"
        local bufc; bufc="$buffer_cur"
        [[ -z "$cursor_new" ]] && cursor_new=-1
        [[ "$buf[$cursor_new]" == ' ' ]] && return
        [[ "$buf[$cursor_new]" == '/' ]] && return
        ((afu_in_p == 1)) && [[ "$buf" != "$bufc" ]] && {
            # there are more than one completion candidates
            zle afu+complete-word
            [[ "$buf" == "$BUFFER" ]] && {
                # the completion suffix was an unambiguous prefix
                afu_in_p=0; buf="$bufc"
            }
            BUFFER="$buf"
            buffer_cur="$bufc"
        }
    }
    zle -N afu+delete-unambiguous-prefix
    function afu-ad-delete-unambiguous-prefix () {
        local afufun="$1"
        local code; code=$functions[$afufun]
        eval "function $afufun () { zle afu+delete-unambiguous-prefix; $code }"
    }
    afu-ad-delete-unambiguous-prefix afu+accept-line
    afu-ad-delete-unambiguous-prefix afu+accept-line-and-down-history
    afu-ad-delete-unambiguous-prefix afu+accept-and-hold

    # run this function just once
#    precmd_functions=("${(@)precmd_functions:#install-auto-fu}")
}

# We should install auto-fu after all configuration changes since it
# inherits 'emacs' keymap and adding key bindings to 'emacs' keymap
# after installing auto-fu has no effect.
# precmd_functions+=install-auto-fu
