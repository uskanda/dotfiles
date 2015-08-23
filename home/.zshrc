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

# Customize to your needs...

# fzf
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# enhancd
if [ -f "/Users/uskanda/.enhancd/zsh/enhancd.zsh" ]; then
    source "/Users/uskanda/.enhancd/zsh/enhancd.zsh"
    export ENHANCD_FILTER="fzf-tmux"
fi
