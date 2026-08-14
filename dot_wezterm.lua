-- ~/.wezterm.lua — macOS / Windows 共通の WezTerm 設定
--
-- 対になるシェル側の実装は ~/.config/shell/ssh-window.sh（chezmoi ソースは
-- dot_config/shell/ssh-window.sh）。対話ログイン目的の ssh を、この設定が用意した
-- mux へ `wezterm cli spawn --new-window` で飛ばし、「1 OS ウィンドウ = 1 リモート
-- ホスト」を維持して nested tmux を避ける。
--
-- chezmoi は 1 ソース → 1 宛先なので、OS 分岐はこのファイルの中で
-- wezterm.target_triple を見て行う。

local wezterm = require 'wezterm'
local act = wezterm.action
local config = wezterm.config_builder()

local is_windows = wezterm.target_triple:find 'windows' ~= nil
local is_macos = wezterm.target_triple:find 'darwin' ~= nil

-- ---------------------------------------------------------------------------
-- 見た目 / 操作感（Alacritty の設定からの移植）
-- ---------------------------------------------------------------------------
-- font_with_fallback にしておくと、UDEV Gothic NF が入っていない端末でも
-- 起動時に落ちずに既定フォントへ落ちる。
config.font = wezterm.font_with_fallback { 'UDEV Gothic NF', 'Menlo', 'Consolas' }
-- WezTerm の既定は 12.0（IncreaseFontSize は 1 回 10% 拡大なので 3 回で ≒ 16.0）。
-- そこから手元で調整した値。
config.font_size = 17.5
-- タブが 1 枚のときはタブバーを隠す。ssh ウィンドウはタブ 1 枚なので
-- ssh-window.sh が付けた "ssh: <host>" がタブバーからは見えなくなるが、
-- 下の format-window-title で OS ウィンドウのタイトルにも同じ文字列を出して
-- いるため、タイトルバー / タスクバー / Alt+Tab では引き続き判別できる。
config.hide_tab_bar_if_only_one_tab = true

-- 右クリックでペースト（Ctrl+Shift+C / Ctrl+Shift+V は WezTerm の既定なので不要）
config.mouse_bindings = {
  {
    event = { Down = { streak = 1, button = 'Right' } },
    mods = 'NONE',
    action = act.PasteFrom 'Clipboard',
  },
}

-- ---------------------------------------------------------------------------
-- タブ / OS ウィンドウのタイトル
-- ---------------------------------------------------------------------------
-- ssh-window.sh は spawn したタブに `wezterm cli set-tab-title` で
-- "ssh: <host>" を付ける。それをそのまま OS ウィンドウのタイトルにも出すことで、
-- Windows のタスクバーや Alt+Tab、macOS の Mission Control でどのウィンドウが
-- どのホストなのかが分かるようにする。
local function title_for(tab)
  local title = tab.tab_title
  if title ~= nil and title ~= '' then
    return title   -- set-tab-title で明示されたもの（= "ssh: <host>"）が最優先
  end

  local p = tab.active_pane
  if p == nil then return 'WezTerm' end

  -- Windows 側からは WSL の中で動いているプロセスが見えず、ペインのタイトルが
  -- wslhost.exe（interop のホストプロセス名）になってしまう。素の状態では
  -- どのウィンドウも wslhost.exe と表示されて役に立たないので、ドメイン名で
  -- 判定して WSL と出す。
  if p.domain_name ~= nil and p.domain_name:match '^WSL:' then
    return 'WSL'
  end

  return p.title or 'WezTerm'
end

wezterm.on('format-window-title', function(tab, pane, tabs, panes, config)
  return title_for(tab)
end)

-- タブバー側も揃える。片方だけ wslhost.exe のままだとちぐはぐになる。
wezterm.on('format-tab-title', function(tab, tabs, panes, config, hover, max_width)
  local width = max_width - 2
  if width < 1 then width = 1 end
  return ' ' .. wezterm.truncate_right(title_for(tab), width) .. ' '
end)

-- ---------------------------------------------------------------------------
-- ペインを閉じる条件
-- ---------------------------------------------------------------------------
-- 'CloseOnCleanExit' にすれば ssh 失敗時にウィンドウが残ってエラーを読めるが、
-- 通常のシェルペインまで巻き添えになる。zsh の `exit` は直前のコマンドの終了
-- ステータスをそのまま返すため、「失敗したコマンドの直後に exit」でペインが
-- 残ってしまう（実測で確認済み）。日常の邪魔になるのでここは既定の 'Close'。
--
-- ssh ウィンドウを失敗時だけ残す仕事は ~/.config/shell/ssh-window.sh 側が持つ。
-- spawn するコマンドを `sh -c 'ssh "$@"; 失敗ならキー待ち'` の形にしてあるので、
-- グローバル設定を触らずに「エラーが読める」を実現できる。
config.exit_behavior = 'Close'

if is_windows then
  -- -------------------------------------------------------------------------
  -- Windows: 既定を WSL に倒しつつ、PowerShell / cmd もすぐ出せるようにする
  -- -------------------------------------------------------------------------
  -- `wsl -l -v` の各 distro が "WSL:<distro>" という名前の domain として登録される。
  -- ssh-window.sh 側もこの命名（WSL:$WSL_DISTRO_NAME）を前提にしている。
  local wsl_domains = wezterm.default_wsl_domains()
  config.wsl_domains = wsl_domains

  -- 普段は WSL に住んでいるので既定を WSL 側にする。distro 名が違う端末でも
  -- 壊れないよう、Ubuntu が無ければ先頭の WSL domain にフォールバックする。
  local preferred = nil
  for _, d in ipairs(wsl_domains) do
    if d.name == 'WSL:Ubuntu' then preferred = d.name end
  end
  if not preferred and wsl_domains[1] then preferred = wsl_domains[1].name end
  if preferred then config.default_domain = preferred end

  -- ランチャ (Ctrl+Shift+D) から選べる起動先。CLI からは
  --   wezterm start                                  → 既定 (WSL)
  --   wezterm start --domain local -- powershell.exe → PowerShell
  -- でも切り替えられる。
  config.launch_menu = {
    { label = 'PowerShell', domain = { DomainName = 'local' }, args = { 'powershell.exe', '-NoLogo' } },
    { label = 'Command Prompt', domain = { DomainName = 'local' }, args = { 'cmd.exe' } },
  }
  if preferred then
    table.insert(config.launch_menu, 1, { label = preferred, domain = { DomainName = preferred } })
  end
elseif not is_macos then
  -- -------------------------------------------------------------------------
  -- Linux (ネイティブ): mux を unix domain に固定する
  -- -------------------------------------------------------------------------
  -- GUI が自前で作る gui-sock-<pid> は WezTerm を再起動するたびにパスが変わる。
  -- 先に起動していた tmux サーバは古い WEZTERM_UNIX_SOCKET を握ったままなので、
  -- そのままだと再起動後に tmux ペインから `wezterm cli` が刺さらない。
  -- 名前付き unix domain はパスが固定なのでこの問題が起きない。
  config.unix_domains = {
    { name = 'unix' },
  }
  -- GUI を引数なしで起動したとき `wezterm connect unix` として振る舞わせ、
  -- すべてのペインを同じ mux に乗せる。
  config.default_gui_startup_args = { 'connect', 'unix' }
end

-- ---------------------------------------------------------------------------
-- macOS で unix domain を使わない理由（消さないこと）
-- ---------------------------------------------------------------------------
-- 以前は macOS でも上と同じ unix domain + `connect unix` を設定していたが、
-- 実測で次の 4 つが起きたのでやめた。GUI はローカル端末として素直に動かす。
--
--  1. ✗ でウィンドウを 1 枚閉じると、その mux の**全ウィンドウ**が消える。
--     WezTerm はクライアント domain のウィンドウを閉じるとき、リモートの
--     セッションを殺さないよう「domain ごと detach」する。GUI ログに
--     `detaching domain` → `domain detached panes: [18 個…]` が残る。
--     この detach だけを止める設定は無い。
--  2. `wezterm cli spawn --domain-name unix` を mux 自身に投げると自己接続になり、
--     spawn 1 回で pane id が 2 → 7 まで飛ぶ（ssh-window.sh 側の注記も参照）。
--  3. `cli list` に実体のないゴーストが残る。`kill-pane` しても "no such pane"
--     で消せず、GUI を繋ぐたびにウィンドウとして一斉に開く。
--  4. GUI を閉じても mux が生き残るため、上記のゴミが日をまたいで蓄積する。
--
-- unix domain を入れた元々の狙いは「tmux ペインから `wezterm cli` を刺す」こと
-- だが、macOS では tmux を使っていない（自動起動は Linux/WSL のみ。CLAUDE.md
-- 参照）ので、そもそも当てはまらない。Linux ネイティブでは tmux を使うため
-- 上の分岐に残してある。

-- ---------------------------------------------------------------------------
-- キーバインド
-- ---------------------------------------------------------------------------
-- 新規タブ/ウィンドウの既定 (Ctrl+Shift+T / Ctrl+Shift+N) は CurrentPaneDomain
-- なのでそのまま使う。ここで DomainName を固定したバインドを足すと、そのタブだけ
-- 別の mux にぶら下がって `wezterm cli` の対象がずれるので注意。
config.keys = {
  -- 起動先ランチャ: WSL / PowerShell / cmd と、登録済み domain を横断で選ぶ
  {
    key = 'd',
    mods = 'CTRL|SHIFT',
    action = act.ShowLauncherArgs { flags = 'FUZZY|LAUNCH_MENU_ITEMS|DOMAINS' },
  },
}

return config
