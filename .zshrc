fpath=(~/.zsh/zsh_completion ${fpath})

#######################################################
#環境変数設定
#######################################################
export LANG=ja_JP.UTF-8
export PAGER=lv
export PATH=/usr/local/bin:/opt/local/bin:/opt/local/sbin:~/Dropbox/Scripts/:/Applications/pTeX.app/teTeX/bin/:$PATH
export TEXINPUTS=$HOME/Documents/bibtex/:$TEXINPUTS
export WORDCHARS='*?_-.[]~=&;!#$%^(){}<>'
export DROPBOXDIR=$HOME/Dropbox

#Environments for Ruby
#export RUBYLIB=/opt/local/lib/ruby/gems/gems/sources-0.0.1/lib:/opt/local/lib/ruby/1.8:/opt/local/lib/ruby/gems/1.8/gems:$RUBYLIB
#export GEM_HOME=/opt/local/lib/ruby/gems/1.8/
export RSPEC=true

export BOOST_ROOT=/opt/local/include/boost-1_35/boost/

#補完設定のおまじない
autoload -U compinit
compinit
#######################################################

source ~/.zsh/scripts/cdd

#シェルの挙動設定
setopt auto_cd # ディレクトリ名だけ打つと打ったディレクトリへcdされる
setopt auto_pushd # cdするとpushdされる　'cd -[TAB]'で幸せになれる
setopt auto_menu #Tabを複数回押すとディレクトリ中のファイルを補完
setopt pushd_ignore_dups #pushdで重複があれば削除してからpush
setopt correct #コマンドのスペルミスを修正する
#setopt correctall #コマンドの引数についてもスペルミス修正を適用 mvとかするとき邪魔
setopt list_packed # compacked complete list display
setopt nolistbeep #補完が曖昧な場合にビープ音を鳴らさない
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

## ターミナルの設定
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

#プロンプトの設定。
#現在は左のプロンプトにディレクトリ、
#右にユーザ名とマシン名表示
autoload colors
colors
  PROMPT="%{${fg[green]}%}%/%%%{${reset_color}%} "
  PROMPT2="%{${fg[red]}%}%_%%%{${reset_color}%} "
#  RPROMPT="[%n@%m]"
  SPROMPT="%{${fg[red]}%}%r is correct? [n,y,a,e]:%{${reset_color}%} "
  [ -n "${REMOTEHOST}${SSH_CONNECTION}" ] &&
    PROMPT="%{${fg[white]}%}${HOST%%.*} ${PROMPT}"

#Host名追加。ssh等の補完
_cache_hosts=(localhost $HOST
  prml{,int,gw,88,89,8a,8b,8f,a0,ra1,ra2,c0,c1,c2,c3,b2,b3}
  ip{pcn,sb}
  192.168.0.1 192.168.1.1 uskanda.com
)

#cd関係の設定
function chpwd() { #cdしたらls
    _reg_pwd_screennum
    precmd
    local DI=`pwd`
    if [ "$DI" = "/Users/kanda" ]; then #ホームディレクトリ以外ならば -a
        ls -G
    else
        ls -AG
    fi
}

case "${TERM}" in screen)
    preexec() {
        echo -ne "\ek#${1%% *}\e\\"
    }
    precmd() {
        echo -ne "\ek$(basename $(pwd))\e\\"
    }
esac


#cdpath=($HOME) #サブディレクトリがない場合、$HOME下のディレクトリを補完しようとする
function cdup() { #親ディレクトリへの移動
  echo
  cd ..
  echo "${fg[red]}---- MOVE TO PARENT DIRECTORY-----"
  zle reset-prompt
}
zle -N cdup
bindkey '^u' cdup # C-uでcd ..

preexec () {
  [ ${STY} ] && echo -ne "\ek${1%% *}\e\\"  # 20070907 修正
}
[ ${STY} ] || tscreen -rx || tscreen -D -RR  # 20070905 修正

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
alias where="command -v"
alias j="jobs -l"
alias du="du -h"
alias df="df -h"
alias su="su -l"
alias rmdir='rm -rf'
alias pd='popd'
alias psa='ps aux'
alias em='emacs'
alias p=$PAGER
#psしてgrep
function psg() {
    psa | head -n 1              # ラベルを表示
    psa | grep $* | grep -v "ps -auxww" | grep -v grep # grep プロセスを除外
}

alias iscoding='nkf --guess'
alias beeps='echo "\a";sleep 1;echo "\a";sleep 1;echo "\a";sleep 1;echo "\a";sleep 0.1;echo "\a";sleep 0.1;echo "\a"'

#ついつい打っちゃうコマンドを矯正

alias less='lv'

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
    alias ls='ls -G'
    alias ruby='ruby -Ku'
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
    ;;
esac


#######################################################

#for Dropbox
function drop() {mv $* $DROPBOXDIR}
function dropcp() {cp $* $DROPBOXDIR}
alias dropcd='cd $DROPBOXDIR'
alias d='dropcd'

#for Typo
alias dc='cd'
alias bc='cd'
alias les='less'

function reload() {
    source ~/.zshrc
    rehash
}

#VMWareのWindowsへログインする
#winb,winc,windでそれぞれ異なるwindowsへのログイン。
function win(){rdesktop -a 16 -r sound -d syori $* -K -g 1270x968 -k ja&}
alias winb='win prml9b'
alias winc='win prml9c'
alias wind='win prml9d'
alias wine='win prml9e'


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
alias -g D=$DROPBOXDIR
alias -g prmlfs='/Volumes/prmlra1.main.ist.hokudai.ac.jp'
##################################################

###########################################################
#サフィックスエイリアス:拡張子に応じた実行プログラムを指定
###########################################################
alias -s java=emacs
alias -s c=emacs
alias -s h=emacs
alias -s C=emacs
alias -s cpp=emacs
alias -s txt=emacs
alias -s xml=emacs
alias -s tex=emacs
alias -s aux=emacs
alias -s el=emacs
alias -s dvi=xdvi
alias -s ps=gv
###########################################################



alias prml='ssh kanda@prmlra1.main.ist.hokudai.ac.jp'
if [ -x /usr/bin/tscreen ]; then
   alias screen='tscreen'
fi

if [ "$TERM" = "screen" ]; then
    precmd(){
       screen -X title $(basename $(print -P "%~"))
   }
fi

alias svn-remove-repos='rm -rf `find ./ -type d -name .svn ! -regex \.svn/. -print`'

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


