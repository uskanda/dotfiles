let s:dein_dir = expand('~/.cache/dein')
let s:dein_repo_dir = s:dein_dir . '/repos/github.com/Shougo/dein.vim'

if &runtimepath !~# '/dein.vim'
  if !isdirectory(s:dein_repo_dir)
    execute '!git clone https://github.com/Shougo/dein.vim' s:dein_repo_dir
  endif
  execute 'set runtimepath^=' . fnamemodify(s:dein_repo_dir, ':p')
endif

if dein#load_state(s:dein_dir)
  call dein#begin(s:dein_dir)
  let s:toml = '~/.config/nvim/dein.toml'
  let s:lazy_toml = '~/.config/nvim/dein_lazy.toml'

  call dein#load_toml(s:toml,      {'lazy': 0})
  call dein#load_toml(s:lazy_toml, {'lazy': 1})

  call dein#end()
  call dein#save_state()
endif

if dein#check_install(['vimproc'])
  call dein#install(['vimproc'])
endif
if dein#check_install()
  call dein#install()
endif


let g:markdown_preview_eager = 1

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"# Vim設定の詳細
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"設定ごとの詳細を書きます。
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"## プラグインの提供機能別索引
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"* [Vimでもともと設定可能な代表的オプションが知りたい - 基本設定](#basics) 
"* [Vimプラグインを管理したい - NeoBundle](#neobundle) 
"* [ファイルに変更があったら自動的にセーブしたい - オートセーブ](#autosave) 
"* [ノーマルモードでのコロンの入力が面倒 - セミコロンをコロン扱いにする](#important_keybind)
"* [インサートモード終了時にEscを押すのが面倒 - 特定の文字入力でインサートモードを終了する](#important_keybind)
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""


""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"## <a name="basics">基本設定
"`````````````````````````````````````````````````````````````
set encoding=utf-8                 " 文字コードをutf-8に設定する
set fileencodings=ucs-bom,utf-8,iso-2022-jp-3,iso-2022-jp,eucjp-ms,euc-jisx0213,euc-jp,sjis,cp932 " ファイルを開いたときに試行するエンコード
set ambiwidth=double               " 全角文字の扱いを改善
set number                         " ファイル左に行番号を表示する
set relativenumber                 " カーソルの位置する行からの差分行数を表示する。set number時の挙動を一部上書きする
set smarttab                       " 頭の余白内で <tab> を打ち込むと空白を挿入
set expandtab                      " tab文字をスペースに展開
set tabstop=4                      " <tab>を押したときの空白文字数
set shiftwidth=4                   " インデント時の空白数
set infercase                      " 小文字で打った単語でも大文字で補完できるようにする
set ignorecase                     " 検索で大文字小文字を区別しない
set textwidth=0                    " 勝手に改行しないようにする
set noswapfile                     " スワップファイルを作成しない
set autoread                       " 他のプログラム等から書き換えられたら自動再読み込み
set nobk                           " バックアップの作成をしないようにする
set ttyfast
set autochdir                      " カレントディレクトリを自動変更
set noundofile
set backspace=indent,eol,start
set timeoutlen=300
set ttimeoutlen=50
"`````````````````````````````````````````````````````````````

"`````````````````````````````````````````````````````````````
"### 読み込むプラグインの指定
"github上に公開されているプラグインの場合、 `NeoBundle {ユーザ名/レポジトリ名}` で
"読み込むことができます。  
"`````````````````````````````````````````````````````````````
"NeoBundle 'h1mesuke/unite-outline'
"NeoBundle 'mattn/emmet-vim'                     "zen-coding
"NeoBundle 'groenewege/vim-less'                 "lessファイル
"NeoBundle 'slim-template/vim-slim'              "slimファイル
"NeoBundle 'kchmck/vim-coffee-script'            "coffeescript
"NeoBundle 'jeffreyiacono/vim-colors-wombat'     "カラースキーム
"`````````````````````````````````````````````````````````````
"### 遅延読み込み
"特定の拡張子のファイルに対してのみ必要なプラグイン等、
"必要なケースが限られているプラグインについては、`NeoBundleLazy` をNeoBundleのかわりに用いることで、
"Vimの起動速度を改善できます。
"`````````````````````````````````````````````````````````````
"NeoBundleLazy 'skwp/vim-rspec', { 'autoload': { 'filetypes': ['ruby', 'eruby', 'haml'] } }
"NeoBundleLazy 'ruby-matchit', { 'autoload' : { 'filetypes': ['ruby', 'eruby', 'haml'] } }
"`````````````````````````````````````````````````````````````
"NeoBundle 'Highlight-UnMatched-Brackets'        "不一致の括弧を強調表示
"NeoBundle 'scrooloose/nerdtree'                 "IDEっぽいファイル表示
"NeoBundle 'tpope/vim-rails'                     "Rails支援
"NeoBundle 'tpope/vim-markdown'
"NeoBundle 'tpope/vim-fugitive'                  "git支援
"NeoBundle 'thinca/vim-quickrun'
"NeoBundle 'YankRing.vim' "ヤンク後C-n,C-pでYankring
""NeoBundle 'kana/vim-arpeggio'
"NeoBundle 'itchyny/lightline.vim'               "ステータスバー/タブバーの情報表示強化
"NeoBundle 'airblade/vim-gitgutter'              "git編集行をウィンドウ左に可視化表示
""NeoBundle 'kakkyz81/evervim'
"NeoBundle 'osyo-manga/vim-gift'
"NeoBundle 'osyo-manga/vim-automatic'            "Window分割支援
"NeoBundle 'rhysd/clever-f.vim'                  "fコマンドを強化
"NeoBundle 'rhysd/conflict-marker.vim'           "VCSのコンフリクト支援
"NeoBundle 'Yggdroot/indentLine'
"NeoBundle 'ap/vim-css-color'
"NeoBundle 'hail2u/vim-css3-syntax'              "css3
"NeoBundle "osyo-manga/shabadou.vim"
"NeoBundle "osyo-manga/vim-watchdogs"            "syntax check
"NeoBundle "jceb/vim-hier"                       "quickfix時のシンタックスハイライト
"NeoBundle "dannyob/quickfixstatus"              "現在行に関するquickfixメッセージをステータスバーに表示
"NeoBundle "sgur/unite-qf"
"NeoBundle "AndrewRadev/switch.vim"
"NeoBundle 'Shougo/vimshell'
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""


""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" ## <a name="builtin">Vimビルトインの追加機能読み込み
"`````````````````````````````````````````````````````````````
" Match Complex Parentheses
source $VIMRUNTIME/macros/matchit.vim
"`````````````````````````````````````````````````````````````

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"## <a name="autosave">ファイルに変更を加えたら自動的にセーブする - Auto-Save 
"[vim-scripts/vim-auto-save](https://github.com/vim-scripts/vim-auto-save)  
"バージョン管理システムを利用しているのならば、毎回ファイルをセーブするコマンドを打つのは時間の無駄です。
"ファイルに変更があったら即セーブするようにしてしまいましょう。
"`````````````````````````````````````````````````````````````
let g:auto_save = 1 "デフォルトで有効にする
let g:auto_save_in_insert_mode = 0 
let g:auto_save_no_updatetime = 1
"`````````````````````````````````````````````````````````````

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"## <a name="important_keybind">影響の大きいキー設定
"### ノーマルモードではセミコロンをコロン扱いする
"`````````````````````````````````````````````````````````````
nnoremap ; :
"`````````````````````````````````````````````````````````````
"### インサートモードで"j"を２回押すとノーマルモードに戻る
"`````````````````````````````````````````````````````````````
inoremap jj <ESC> " in insert mode, jj means <ESC>.
"`````````````````````````````````````````````````````````````

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"## <a name="unite">Unite.vim
"[Shougo/unite.vim](https://github.com/Shougo/unite.vim)  
"使いやすい検索インタフェースを提供してくれます。
"`````````````````````````````````````````````````````````````
" 入力モードで開始する
let g:unite_enable_start_insert=1
" 大文字小文字を区別しない
let g:unite_enable_ignore_case = 1
let g:unite_enable_smart_case = 1
"`````````````````````````````````````````````````````````````
"### 現在のバッファと同一プロジェクト内のファイル検索
"キーバインド: ,p
"VCSの同一管理下にあるファイルを同一プロジェクトとみなし、
"同一プロジェクト内のファイル検索を行います。
"`````````````````````````````````````````````````````````````
nnoremap <silent> ,p :<C-u>call <SID>unite_project('-start-insert')<CR>

function! s:unite_project(...)
  let opts = (a:0 ? join(a:000, ' ') : '')
    let dir = unite#util#path2project_directory(expand('%'))
      execute 'Unite' opts 'file_rec:' . dir
endfunction
"`````````````````````````````````````````````````````````````

"http://blog.monochromegane.com/blog/2013/09/18/ag-and-unite/
" grep検索
nnoremap <silent> ,s  :<C-u>Unite grep:. -buffer-name=search-buffer<CR>
" カーソル位置の単語をgrep検索
nnoremap <silent> ,cs :<C-u>Unite grep:. -buffer-name=search-buffer<CR><C-R><C-W>
" grep検索結果の再呼出
nnoremap <silent> ,r  :<C-u>UniteResume search-buffer<CR>

" unite grep に ag(The Silver Searcher) を使う
if executable('ag')
  let g:unite_source_grep_command = 'ag'
  let g:unite_source_grep_default_opts = '--nogroup --nocolor --column'
  let g:unite_source_grep_recursive_opt = ''
endif

nnoremap <silent> ,uo :<C-u>Unite outline<CR>
nnoremap <silent> ,uh :<C-u>Unite help<CR>
" ファイル一覧
nnoremap <silent> ,f :<C-u>UniteWithBufferDir -buffer-name=files file<CR>
" レジスタ一覧
nnoremap <silent> ,r :<C-u>Unite -buffer-name=register register<CR>
" " 常用セット
nnoremap <silent> ,, :<C-u>Unite buffer file_mru<CR>
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"## 補完 - Neocomplete
"[Shougo/neocomplete.vim](https://github.com/Shougo/neocomplete.vim)
"`````````````````````````````````````````````````````````````
if has("lua")
    let g:acp_enableAtStartup = 0
    let g:neocomplete#enable_at_startup = 1
    let g:neocomplete#enable_smart_case = 1
    let g:neocomplete#auto_completion_start_length = 2
    let g:neocomplete#manual_completion_start_length = 0
    let g:neocomplete#sources#syntax#min_keyword_length = 3
    let g:neocomplete#min_keyword_length = 2
    let g:neocomplete#lock_buffer_name_pattern = '\*unite\*'
    let g:neocomplete#enable_prefetch = 1
    
    let g:neocomplete#enable_camel_case_completion = 0
    let g:neocomplete#enable_underbar_completion = 1
    inoremap <expr><CR>  neocomplete#smart_close_popup() . "\<CR>"
    inoremap <expr><TAB>  pumvisible() ? "\<C-n>" : "\<TAB>"
    
    autocmd FileType css,less,sass setlocal omnifunc=csscomplete#CompleteCSS
    autocmd FileType html,markdown setlocal omnifunc=htmlcomplete#CompleteTags
    autocmd FileType javascript setlocal omnifunc=javascriptcomplete#CompleteJS
    autocmd FileType python setlocal omnifunc=pythoncomplete#Complete
    autocmd FileType xml setlocal omnifunc=xmlcomplete#CompleteTags
end
"`````````````````````````````````````````````````````````````

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"## スニペット - Neosnippet
"[Shougo/neosnippet.vim](https://github.com/Shougo/neosnippet.vim)
"`````````````````````````````````````````````````````````````
" Plugin key-mappings.
imap <C-k>     <Plug>(neosnippet_expand_or_jump)
smap <C-k>     <Plug>(neosnippet_expand_or_jump)
xmap <C-k>     <Plug>(neosnippet_expand_target)

" SuperTab like snippets behavior.
imap <expr><TAB> neosnippet#expandable_or_jumpable() ?
\ "\<Plug>(neosnippet_expand_or_jump)"
\: pumvisible() ? "\<C-n>" : "\<TAB>"
smap <expr><TAB> neosnippet#expandable_or_jumpable() ?
\ "\<Plug>(neosnippet_expand_or_jump)"
\: "\<TAB>"

" For snippet_complete marker.
if has('conceal')
  set conceallevel=2 concealcursor=i
endif
"`````````````````````````````````````````````````````````````

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"## <a name="nerdtree">ファイルツリーを表示 - NERDTree
"### [NERDTree](https://github.com/scrooloose/nerdtree)
"IDEっぽいファイル表示
"`````````````````````````````````````````````````````````````
map ,d :execute 'NERDTreeToggle ' . getcwd()<CR>
"`````````````````````````````````````````````````````````````

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"## <a name="clever-f">fでの検索を強化 - clever-f
"[clever-f](https://github.com/rhysd/clever-f.vim)
"`````````````````````````````````````````````````````````````
let g:clever_f_smart_case = 1
"`````````````````````````````````````````````````````````````

"`````````````````````````````````````````````````````````````
"## <a name="evervim">Evernote on Vim - Evervim
"### キーバインド 
"`````````````````````````````````````````````````````````````
nnoremap <silent> ,el :<C-u>EvervimNotebookList<CR>
nnoremap <silent> ,eT :<C-u>EvervimListTags<CR>
nnoremap <silent> ,en :<C-u>EvervimCreateNote<CR>
nnoremap <silent> ,eb :<C-u>EvervimOpenBrowser<CR>
nnoremap <silent> ,ec :<C-u>EvervimOpenClient<CR>
nnoremap ,es :<C-u>EvervimSearchByQuery<SPACE>
nnoremap <silent> ,et :<C-u>EvervimSearchByQuery<SPACE>tag:todo -tag:done -tag:someday<CR>
nnoremap <silent> ,eta :<C-u>EvervimSearchByQuery<SPACE>tag:todo -tag:done<CR>
"`````````````````````````````````````````````````````````````

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"## <a name="fugitive">git支援 - fugitive
"### キーバインド
"`````````````````````````````````````````````````````````````
nnoremap ,gd :<C-u>Gdiff<Enter>
nnoremap ,gs :<C-u>Gstatus<Enter>
nnoremap ,gl :<C-u>Glog<Enter>
nnoremap ,ga :<C-u>Gwrite<Enter>
nnoremap ,gc :<C-u>Gcommit<Enter>
nnoremap ,gC :<C-u>Git commit --amend<Enter>
nnoremap ,gp :<C-u>Git push origin<Enter>
nnoremap ,gb :<C-u>Gblame<Enter>
"`````````````````````````````````````````````````````````````

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" ## <a name="filetypes">拡張子ごとの動作設定
"`````````````````````````````````````````````````````````````
"autocmd BufNewFile,BufRead *.less set filetype=css
autocmd BufNewFile,BufRead *.as set filetype=actionscript " .asはactionscriptとみなす
"`````````````````````````````````````````````````````````````


""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"## ウィンドウ分割のルール設定 - automatic.vim
"`````````````````````````````````````````````````````````````
let g:automatic_config = [
\   {
\       "match" : {
\           "bufname" : '__EVERVIM_LIST__',
\       },
\       "set" : {
\           'columns' : 30,
\           'move' : "left",
\           'is_close_focus_out' : 1,
\       },
\   },
\]
"`````````````````````````````````````````````````````````````


""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"## <a name="lightline">ステータスラインを便利に - lightline
"`````````````````````````````````````````````````````````````
let g:lightline = {
\ 'colorscheme': 'wombat',
\ 'component': {
\   'readonly': '%{&readonly?"⭤":""}',
\   'dir': '%.50(%{expand("%:h:s?\\S$?\\0/?")}%)',
\ },
\ 'active': {
\   'left': [ [ 'mode', 'paste'],  ['readonly', 'dir', 'filename' ], ['fugitive', 'gitgutter', 'modified' ] ]
\ },
\ 'component_function': {
\   'fugitive': 'MyFugitive',
\   'gitgutter': 'MyGitGutter',
\ },
\ 'separator': { 'left': '⮀', 'right': '⮂' },
\ 'subseparator': { 'left': '⮁', 'right': '⮃' }
\ }


function! MyFugitive()
  try
    if &ft !~? 'vimfiler\|gundo' && exists('*fugitive#head')
      let _ = fugitive#head()
      return strlen(_) ? '⭠ '._ : ''
    endif
  catch
  endtry
  return ''
endfunction

function! MyGitGutter()
  if ! exists('*GitGutterGetHunkSummary')
        \ || ! get(g:, 'gitgutter_enabled', 0)
        \ || winwidth('.') <= 90
    return ''
  endif
  let symbols = [
        \ g:gitgutter_sign_added . ' ',
        \ g:gitgutter_sign_modified . ' ',
        \ g:gitgutter_sign_removed . ' '
        \ ]
  let hunks = GitGutterGetHunkSummary()
  let ret = []
  for i in [0, 1, 2]
    if hunks[i] > 0
      call add(ret, symbols[i] . hunks[i])
    endif
  endfor
  return join(ret, ' ')
endfunction


"let g:lightline.tabline = {
"      \ 'left': [ [ 'tabs' ] ],
"      \ 'right': [ [ 'close' ] ] }

" ## Tablineキーバインド
" TODO: use prefix key
" Tab jump
for n in range(1, 9)
  execute 'nnoremap <silent> t'.n  ':<C-u>tabnext'.n.'<CR>'
endfor
" t1 で1番左のタブ、t2 で1番左から2番目のタブにジャンプ

nmap <silent> tc :tablast <bar> tabnew<CR>
" tc 新しいタブを一番右に作る
nmap <silent> tx :tabclose<CR>
" tx タブを閉じる
nmap <silent> tn :tabnext<CR>
nmap <silent> tt :tabnext<CR>
" tn 次のタブ
nmap <silent> tp :tabprevious<CR>
" tp 前のタブ
"`````````````````````````````````````````````````````````````


" vim-anzu
" mapping
nmap n <Plug>(anzu-n-with-echo)
nmap N <Plug>(anzu-N-with-echo)
nmap * <Plug>(anzu-star-with-echo)
nmap # <Plug>(anzu-sharp-with-echo)
" clear status
nmap <Esc><Esc> <Plug>(anzu-clear-search-status)
" statusline
set statusline=%{anzu#search_status()}

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" ## true/false等を簡単に切り替える - switch
"`````````````````````````````````````````````````````````````
nnoremap - :Switch<cr>
"`````````````````````````````````````````````````````````````

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" ## gitgutter
" CUIだとノーマルモードでタイプしたキーのゴミが稀に残るので対策
"`````````````````````````````````````````````````````````````
if !has("gui_running")
    let g:gitgutter_realtime = 0
endif
"`````````````````````````````````````````````````````````````

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" ## watchdogs
"`````````````````````````````````````````````````````````````
let g:quickrun_config = {
\   "watchdogs_checker/_" : {
\       "hook/close_quickfix/enable_exit" : 1,
\   }
\}
" Rubocop
if executable('rubocop')
    let g:quickrun_config["ruby/watchdogs_checker"] = {
    \       "type" : "watchdogs_checker/rubocop"
    \   }
endif
let g:watchdogs_check_BufWritePost_enable = 1
"call watchdogs#setup(g:quickrun_config)
"`````````````````````````````````````````````````````````````

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
":Renameでファイルリネーム
"`````````````````````````````````````````````````````````````
command! -nargs=1 -complete=file Rename f <args>|call delete(expand('#'))
"`````````````````````````````````````````````````````````````

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" indentLine
"`````````````````````````````````````````````````````````````
let g:indentLine_color_term = 111
let g:indentLine_color_gui = '#708090'
let g:indentLine_char = '¦'
"`````````````````````````````````````````````````````````````
    
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"## ローカル設定用vimrc読み込み
"端末単位での設定や、パスワードの記載等をvimrc.localに記載する
"`````````````````````````````````````````````````````````````
"if filereadable(expand('~/.vimrc.local'))
"  source ~/.vimrc.local
"endif
"`````````````````````````````````````````````````````````````

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" <a name="others">その他設定
"`````````````````````````````````````````````````````````````
filetype plugin indent on          " ファイル形式検出、プラグイン、インデントを ON
"colorscheme wombat
"`````````````````````````````````````````````````````````````

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" <a name="highlight_cursor">カーソル位置の行, 列ハイライト
"`````````````````````````````````````````````````````````````
augroup vimrc-auto-cursorline
    autocmd!
    autocmd CursorMoved,CursorMovedI * call Auto_cursorline('CursorMoved')
    autocmd CursorHold,CursorHoldI * call Auto_cursorline('CursorHold')
    autocmd WinEnter * call Auto_cursorline('WinEnter')
    autocmd WinLeave * call Auto_cursorline('WinLeave')

    let g:cursorline_lock = 0
    function! Auto_cursorline(event)
        if a:event ==# 'WinEnter'
            setlocal cursorline
            setlocal cursorcolumn
            let g:cursorline_lock = 2
        elseif a:event ==# 'WinLeave'
            setlocal nocursorline
            setlocal nocursorcolumn
        elseif a:event ==# 'CursorMoved'
            if g:cursorline_lock
                if 1 < g:cursorline_lock
                    let g:cursorline_lock = 1
                else
                    setlocal nocursorline
                    setlocal nocursorcolumn
                    let g:cursorline_lock = 0
                endif
            endif
        elseif a:event ==# 'CursorHold'
            setlocal cursorline
            setlocal cursorcolumn
            let g:cursorline_lock = 1
        endif
    endfunction
augroup END
"`````````````````````````````````````````````````````````````


