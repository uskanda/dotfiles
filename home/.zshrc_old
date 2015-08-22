#######################################################
#環境変数設定
#######################################################
export LANG=ja_JP.UTF-8
export PAGER=lv
export PATH=/usr/local/bin:/opt/local/bin:/opt/local/sbin:$PATH
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

#emacs風のキーバインドにする。
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

autoload -Uz chpwd_recent_dirs cdr add-zsh-hook
add-zsh-hook chpwd chpwd_recent_dirs
zstyle ":chpwd:*" recent-dirs-max 1000


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
