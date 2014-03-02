#######################################################
# ##zsh-completionsの読み込み
#``````````````````````````````````````````````````````
fpath=(~/.zsh/zsh-completions-selected ${fpath})
#``````````````````````````````````````````````````````

#######################################################
#環境変数設定
#######################################################
export LANG=ja_JP.UTF-8
export PAGER=lv
export PATH=/usr/local/bin:/opt/local/bin:/opt/local/sbin:$PATH
export TEXINPUTS=$HOME/Documents/bibtex/:$TEXINPUTS
export WORDCHARS='*?_-.[]~=&;!#$%^(){}<>'
export DOCKER_HOST=localhost

# anyenv
if [ -d ${HOME}/.anyenv ] ; then
    export PATH="$HOME/.anyenv/bin:$PATH"
    eval "$(anyenv init -)"
    for XENVDIR in `find $HOME/.anyenv/envs -type d -d 1`
    do
        export PATH=$XENVDIR/shims:$PATH
    done

fi

#Environments for Ruby
export RSPEC=true

#補完設定のおまじない
autoload -U compinit
compinit
#######################################################

#######################################################
#シェルの挙動設定
setopt auto_cd # ディレクトリ名だけ打つと打ったディレクトリへcdされる
setopt auto_pushd # cdするとpushdされる　'cd -[TAB]'で幸せになれる
setopt auto_menu #Tabを複数回押すとディレクトリ中のファイルを補完
setopt pushd_ignore_dups #pushdで重複があれば削除してからpush
setopt correct #コマンドのスペルミスを修正する
#setopt correctall #コマンドの引数についてもスペルミス修正を適用 mvとかするとき邪魔
setopt list_packed # compacked complete list display
setopt nobeep #補完が曖昧な場合にビープ音を鳴らさない
setopt glob_dots
setopt rmstar_wait #"rm *"実行時に確認する
setopt complete_aliases
autoload zed
autoload zmv
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

#emacs風のキーバインドにする。以下主なキーバインドの例
#C-a 行頭へジャンプ
#C-e 行末へジャンプ
#C-k カーソルから行末までを削除
#C-w カーソルから行頭までを削除
#C-l スクリーンをクリア
#bindkey -v #vi風のキーバインドにしたければこちら
bindkey -e
#######################################################


#######################################################
# コマンドヒストリーの設定
#######################################################
HISTFILE=~/.zsh/zsh_history
HISTSIZE=1000000
SAVEHIST=1000000
setopt hist_ignore_dups # 直近と同じコマンドはヒストリに入れない
setopt hist_ignore_all_dups #以前に打ったことのあるコマンドはヒストリに入れない
setopt hist_ignore_space #先頭にスペースを入れてコマンドを打つとヒストリーに入らない
setopt share_history # share command history data
setopt extended_history
setopt hist_reduce_blanks    # 余分な空白は詰めて記録
function history-all { history -E 1 }
#ヒストリーの検索設定。C-p,C-nで検索可能
autoload history-search-end
zle -N history-beginning-search-backward-end history-search-end
zle -N history-beginning-search-forward-end history-search-end
bindkey "^p" history-beginning-search-backward-end
bindkey "^n" history-beginning-search-forward-end
bindkey "\\ep" history-beginning-search-backward-end
bindkey "\\en" history-beginning-search-forward-end
#######################################################

#######################################################
## ターミナルの設定
#######################################################
unset LSCOLORS
case "${TERM}" in
xterm)
  export TERM=xterm-color
  ;;
kterm)
  export TERM=kterm-color
  # set BackSpace control character
  stty erase
  ;;
cons25)
  unset LANG
  export LSCOLORS=ExFxCxdxBxegedabagacad
  export LS_COLORS='di=01;34:ln=01;35:so=01;32:ex=01;31:bd=46;34:cd=43;34:su=41;30:sg=46;30:tw=42;30:ow=43;30'
  zstyle ':completion:*' list-colors \
    'di=;34;1' 'ln=;35;1' 'so=;32;1' 'ex=31;1' 'bd=46;34' 'cd=43;34'
  ;;
esac

# set terminal title including current directory
#
case "${TERM}" in
kterm*|xterm*)
  precmd() {
    echo -ne "\033]0;${USER}@${HOST%%.*}:${PWD}\007"
  }
  export LSCOLORS=exfxcxdxbxegedabagacad
  export LS_COLORS='di=34:ln=35:so=32:pi=33:ex=31:bd=46;34:cd=43;34:su=41;30:sg=46;30:tw=42;30:ow=43;30'
  zstyle ':completion:*' list-colors \
    'di=34' 'ln=35' 'so=32' 'ex=31' 'bd=46;34' 'cd=43;34'
  ;;
esac
#######################################################

#######################################################
#プロンプトの設定。
#現在は左のプロンプトにディレクトリ、
#右にユーザ名とマシン名表示
#######################################################
autoload colors
colors
  PROMPT="%{${fg[green]}%}%/%%%{${reset_color}%} "
  PROMPT2="%{${fg[red]}%}%_%%%{${reset_color}%} "
#  RPROMPT="[%n@%m]"
  SPROMPT="%{${fg[red]}%}%r is correct? [n,y,a,e]:%{${reset_color}%} "
  [ -n "${REMOTEHOST}${SSH_CONNECTION}" ] &&
    PROMPT="%{${fg[white]}%}${HOST%%.*} ${PROMPT}"

autoload -Uz vcs_info

# 表示フォーマットの指定
# %b ブランチ情報
# %a アクション名(mergeなど)
zstyle ':vcs_info:*' formats '[%b]'
zstyle ':vcs_info:*' actionformats '[%b|%a]'
precmd () {
    psvar=()
    LANG=en_US.UTF-8 vcs_info
    [[ -n "$vcs_info_msg_0_" ]] && psvar[1]="$vcs_info_msg_0_"
}

# バージョン管理されているディレクトリにいれば表示，そうでなければ非表示
RPROMPT="%1(v|%F{green}%1v%f|)"
#######################################################

if [[ -f $HOME/.zsh/antigen/antigen.zsh ]]; then
  source $HOME/.zsh/antigen/antigen.zsh

  # Bundles from the default app.
  antigen-bundles <<EOBUNDLES
  autojump
  heroku
  npm
  osx
  urltools
  zsh-users/zsh-syntax-highlighting
EOBUNDLES

  antigen-apply
fi

source ~/.zsh/cdd/cdd

#######################################################
#cdの設定
#######################################################
function chpwd() { #cdしたらls
    _cdd_chpwd
    #precmd
    local DI=`pwd`
    if [ "$DI" = "/Users/kanda" ]; then #ホームディレクトリ以外ならば -a
        ls -G
    else
        ls -AG
    fi
}

#cdpath=($HOME) #サブディレクトリがない場合、$HOME下のディレクトリを補完しようとする
function cdup() { #親ディレクトリへの移動
  echo
  cd ..
  echo "${fg[red]}---- MOVE TO PARENT DIRECTORY-----"
  zle reset-prompt
}
zle -N cdup
bindkey '^u' cdup # C-uでcd ..
#######################################################

#######################################################
#エイリアス設定
#######################################################
#ls関係のエイリアス
alias l='ls'
alias la="ls -A"
alias lf="ls -F"
alias ll="ls -l"
alias lal="ls -Al"
alias ltr="ls -ltr"
alias ltr="ls -altr"

#head/tailエイリアス
alias f="tail -f"
alias F="tail -F"
alias h="head -n 30"
alias t="tail -n 30"
alias tailf='tail -f'
alias follow='tail -f'

#その他のエイリアス・関数
alias g="git"
alias gi="git"
alias where="command -v"
alias du="du -h"
alias df="df -h"
alias su="su -l"
alias rmdir='rm -rf'
alias pd='popd'
alias psa='ps aux'
alias em='emacs'
alias p=$PAGER
alias agp='ag --pager="less -R"'

#######################################################
#OS別の設定
#######################################################

case $OSTYPE in
  linux*)
    alias pxdvi='xdvi'
    alias ls='ls --color'
    alias -s gif=display
    alias -s jpg=display
    alias -s jpeg=display
    alias -s png=display
    alias -s bmp=display
    alias -s pdf=acroread
    alias -s html=w3m
    alias -s xhtml=w3m
    alias emacs='emacsclient'
    alias emacsstart='command emacs'
    ;;
  darwin*)
    #export VIMRUNTIME=/Applications/MacVim.app/Contents/Resources/vim/runtime/
    alias less='/Applications/MacVim.app/Contents/Resources/vim/runtime/macros/less.sh'
    alias ls='ls -G'
    alias vi='/Applications/MacVim.app/Contents/MacOS/Vim'
    alias v='mvim'
    alias mvim='mvim --remote-tab-silent'
    alias o='open'
    alias oa='open -a'
    alias vlc="open -a VLC"
    alias pv="open -a Preview"
    alias qs="open -a Quicksilver"
    alias preview="open -a Preview"
    alias keynote="open -a Keynote"
    alias emacs="open -a /Applications/Emacs.app"
    alias pathfinder="open -a \"Path Finder\""
    alias pf="open -a \"Path Finder\""
    alias tac="gtac"
    alias -s gif=preview
    alias -s jpg=preview
    alias -s jpeg=preview
    alias -s png=preview
    alias -s bmp=preview
    alias -s pdf=preview
    alias -s html=firefox
    alias -s xhtml=firefox
    alias dev='cd ~/Developments'
    ;;
esac
#######################################################

###########################################################
#for Typo
###########################################################
alias dc='cd'
alias bc='cd'
alias les='less'
###########################################################

###################################################
#グローバルエイリアス:先頭以外でも使えるエイリアス
##################################################
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
##################################################

###########################################################
#サフィックスエイリアス:拡張子に応じた実行プログラムを指定
###########################################################
alias -s java=mvim
alias -s c=mvim
alias -s h=mvim
alias -s C=mvim
alias -s cpp=mvim
alias -s txt=mvim
alias -s xml=mvim
alias -s tex=mvim
alias -s aux=mvim
alias -s el=mvim
alias -s dvi=xdvi
alias -s ps=gv
###########################################################

alias rake="noglob rake"
compdef -d rake

###########################################################
#screen設定
###########################################################
if which tmux > /dev/null; then
    WHOAMI=$(whoami)
    if tmux has-session -t $WHOAMI 2>/dev/null; then
        if [ $SHLVL = 1 ]; then
            tmux -2 attach-session -t $WHOAMI
        fi
    else
        tmux -2 new-session -s $WHOAMI
    fi
    function show-current-dir-as-window-name() {
        tmux set-window-option window-status-format " #I:${PWD:t} " > /dev/null
    }

    show-current-dir-as-window-name
    add-zsh-hook chpwd show-current-dir-as-window-name

else
    # One might want to do other things in this case, 
    # here I print my motd, but only on servers where 
    # one exists

    # If inside tmux session then print MOTD
    MOTD=/etc/motd.tcl
    if [ -f $MOTD ]; then
        $MOTD
    fi
fi


###############################################
#sshしたときにscreenのウィンドウを新規生成する
###############################################
function ssh_screen(){
 eval server=\${$#}
 screen -t $server ssh "$@"
}
if [ x$TERM = xscreen ]; then
  alias ssh=ssh_screen
fi

[[ $EMACS = t ]] && unsetopt zle
###############################################


###############################################
#インクリメンタル補完設定
#http://github.com/hchbaw/auto-fu.zsh
###############################################
source ~/.zsh/completion.zsh
###############################################

###############################################
# load percol sources
###############################################
for f (~/.zsh/percol-sources/*) source "${f}"
bindkey '^r' percol-select-history
###############################################


###############################################
#その他関数
###############################################
function reload() {
    source ~/.zshrc
    rehash
}
#psしてgrep
function psg() {
    psa | head -n 1              # ラベルを表示
    psa | grep $* | grep -v "ps -auxww" | grep -v grep # grep プロセスを除外
}

alias beeps='echo "\a";sleep 1;echo "\a";sleep 1;echo "\a";sleep 1;echo "\a";sleep 0.1;echo "\a";sleep 0.1;echo "\a"'
alias svn-remove-repos='rm -rf `find ./ -type d -name .svn ! -regex \.svn/. -print`'
###############################################

install-auto-fu
