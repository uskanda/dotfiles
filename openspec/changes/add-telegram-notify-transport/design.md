## Context

現状の通知経路（`dot_local/bin/`）:

```
hook(JSON) → claude-notify-hook → claude-notify-nag（grace/繰り返し）
                                → claude-notify
                                     ├ macOS      : VOICEVOX(:50021) → say
                                     ├ native Win : powershell → claude-notify.ps1 → VOICEVOX → SAPI5
                                     ├ WSL2       : powershell interop → 〃
                                     └ container/SSH : 案1 daemon(:50090) → 案2 ntfy → ベル
```

制約と前提:

- **Bot は他 Bot および自分自身が送信したメッセージを `getUpdates` で受信できない**（Telegram の仕様。ループ防止のため「bots will ignore messages coming from other bots」）。したがって「フックが Bot で送信 → 同じ／別の Bot が読んで発話」という素直な構成は成立しない。リレーには「送信者が Bot ではない」identity を挟む必要がある。
- リモート側（devcontainer / SSH）は使い捨てで、対話ログインや長期セッションファイルを置きたくない。逆に手元マシン（Mac/Win）は常駐を持てる。
- 既存スクリプトは bash + Python 3 標準ライブラリのみで書かれており、`config.env`（chezmoi テンプレート）で秘密を渡す方式が確立している。この様式を崩さない。
- 既存 `voice` 経路を壊さないことが最優先。既定値は現行動作のままとする。

## Goals / Non-Goals

**Goals:**
- SSH 先 / devcontainer から、ポート転送も自前サーバも無しに「手元の VOICEVOX で発話」を成立させる。
- 同じ 1 通でスマホにも通知が届く（外出時は Telegram 通知だけで用が足りる）。
- 既存 `voice` モードと排他選択でき、既定は `telegram`（未配線端末は `voice` へフォールバックするので無音にはならない）。
- 追加パッケージ無し（bash + curl + Python 3 標準ライブラリ）。
- 秘密の置き場所は既存方式（`chezmoi.toml` の `[data.claudeNotify]` → `config.env`）に揃える。

**Non-Goals:**
- Telegram から Claude Code を操作する（返信で指示を送る、`/mute` 等のコマンド）機能。将来拡張として設計上妨げないだけに留める。
- 案1（HTTP デーモン）/ 案2（ntfy）の置き換え・削除。`voice` モードとして残す。
- Linux デスクトップを受信側にすること（受信側は macOS / Windows のみ）。
- 通知内容の充実化（差分要約、ツール名、所要時間などの送信）。本文は既存発話文＋最小メタデータに限定する。
- `voice` と `telegram` の同時実行（`both`）。要望どおり択一とする。

## Decisions

### D1: リレー構成は「チャンネル → 連携ディスカッショングループ」を採用（採用案 A）

```
リモート/ローカルの hook
   └─ 送信Bot(sendMessage) ──> 非公開チャンネル      … スマホ通知はここから届く
                                    │ Telegram が自動転送（sender_chat = チャンネル）
                                    ▼
                              連携ディスカッショングループ
                                    │ getUpdates（長ポーリング）
                                    ▼
                              受信Bot = claude-notify-telegram-bot（手元 Mac/Win 常駐）
                                    └─ claude-notify / claude-notify.ps1 → VOICEVOX
```

チャンネル投稿が連携グループへ自動転送されると、グループ側のメッセージは「チャンネルが送信者」（`sender_chat` = チャンネル、`is_automatic_forward` = true）として扱われるため、Bot でも受信できる。これが「Bot は Bot のメッセージを読めない」制約を回避する唯一の Bot API 内の手段。

**検討した代替案:**

- **案 B: 受信側を Telethon（ユーザーアカウント）にする** — 送信は Bot の `sendMessage`、受信は手元 PC で自分の Telegram アカウントとしてログインして Bot のメッセージを読む。Telegram 側の設定は「Bot を作って `/start`」だけで最小、動作の確実性も高い。却下理由: `api_id`/`api_hash` の取得と対話ログインが必要で `chezmoi apply` だけでは再現できず、**アカウント全権のセッションファイル**を各 PC に置くことになる（Bot トークン漏洩とは影響度が桁違い）。追加依存（telethon）も発生する。→ **D2 の検証が失敗した場合の差し替え案として保持**（Migration Plan 参照）。
- **案 C: Bot 1 個で往復** — 送信も受信も同一 Bot。Telegram の仕様上、自分が送ったメッセージの更新は届かないため成立しない。却下。
- **案 D: Telegram は通知のみ、発話は案1/案2 のまま** — 実装は最小だが「SSH/devcontainer で発話できない」という当初の問題が解決しない。却下。
- **案 E: 公開 ntfy.sh を案2 の URL に設定する** — 既存コードのままで到達性は得られるが、トピック名が実質的な共有秘密で誰でも購読でき、スマホ通知も別アプリになる。Telegram のほうが運用が素直。却下（ただし `voice` モードの案2 としては引き続き利用可能）。

### D2: 送信 Bot と受信 Bot を分離する（Bot 2 個）

同一 Bot を「チャンネル投稿者」と「グループ購読者」に兼用すると、自動転送されたコピーが *自分の投稿の派生* とみなされて配信されないリスクがある（仕様上のグレーゾーン）。加えて、リモート（devcontainer / 他人の環境に近い場所）に置くトークンは「チャンネルへ投稿する権限だけ」にしたい。よって:

- **送信 Bot**: チャンネルの管理者。トークンはリモート含む全マシンの `config.env` に置く。漏洩時の最大被害は「チャンネルへ投稿される」こと。
- **受信 Bot**: 連携グループのメンバー（プライバシーモード無効、または管理者）。トークンは手元マシンだけに置く。

受信 Bot は 1 トークン 1 ポーラーに限る（`getUpdates` は同一トークンの並行呼び出しで HTTP 409）。Mac と Windows の両方で鳴らしたい場合は受信 Bot を 2 個作り、両方を同じグループに入れる（自動転送は両方に配信される）。

### D3: メッセージ書式は「1 行目 = 発話文、2 行目 = マーカー行」

```
✅ dotfiles の作業が完了しました
#claude_notify kind=done host=devbox repo=dotfiles sid=ab12cd34
```

- 1 行目をそのまま発話文にすることで、発話文の生成ロジック（`claude-notify-hook` のリポジトリ名付与）を送信側に集約でき、受信側は「整形して読むだけ」になる。JSON 本文にしないのは、スマホの通知プレビューで読めることを優先したため。
- 2 行目のマーカーで「Claude Code 由来か」を判定する。人間の雑談や他アプリの投稿を誤って読み上げない防壁であり、将来 `kind` で挙動を分けるための拡張点でもある。`#claude_notify` をハッシュタグにしてあるので Telegram 側の検索・フィルタでも使える。
- `parse_mode` は指定しない。Markdown/HTML パースを有効にすると、リポジトリ名に `_` や `*` が含まれた瞬間に 400 で送信失敗する。

### D4: モードは `CLAUDE_NOTIFY_MODE`（`telegram` | `voice`、既定 `telegram`）

- 置き場所は既存様式に合わせて `~/.config/claude-notify/config.env`（`chezmoi.toml` の `[data.claudeNotify] mode`）。端末ごとに上書きできる。
- **既定は `telegram`**。Telegram 経路が「どの環境でも同じ手順で動く」唯一の経路なので、これを標準に据え、手元で直接鳴らしたい端末だけ `mode = "voice"` で opt-out する。既定を `voice` にしておくと、通知が欲しい環境（SSH / devcontainer）ほど毎回追加設定が要るという逆転が起きる。
- 既定変更の副作用として「Telegram を配線していない端末が無音になる」ため、`telegram` かつトークン / チャット ID が空のときだけ `voice` へフォールバックする（警告 1 行付き）。厳密な択一（未設定ならベルのみ）にすると、`chezmoi apply` した瞬間に全端末が黙るため実用に耐えない。逆に「設定済みだが送信失敗」では `voice` へ落とさない（リモートでは案1/案2 を無駄に叩いてフックが遅くなるだけ）。
- **`config.env` は `${VAR:-...}` 形式で出力する**。現行の `config.env` は `KEY="value"` で無条件代入しており、`. config.env` が既存の環境変数を踏み潰す。一時的な切り戻し（`CLAUDE_NOTIFY_MODE=voice claude-notify ...`）とデバッグを成立させるため、新規キーは環境変数優先で書き出す。
- 不正値は `voice` として扱い警告のみ。通知系スクリプトがフックを失敗させてはならないため、どの失敗経路でも終了コードは 0。

### D5: `telegram` モードでは nag を繰り返さない（grace 抑制は維持）

- 繰り返しをそのまま Telegram 送信に置換すると 10 分毎にスマホが鳴りチャットも汚れる。ユーザー判断により `telegram` では 1 通のみ。
- ただし grace（既定 3 秒）は残す。これは「turn 終了時の Notification → 直後の Stop」で確認メッセージを取り消す仕組みであり、無くすと完了 1 通＋不要な確認 1 通が毎回飛ぶ。`claude-notify-nag` の `start` を「grace 後 1 回だけ実行して終了」に分岐させるのが最小差分。
- `voice` モードの nag（`CLAUDE_NAG_INTERVAL` 毎の再発話）は変更しない。

### D6: 受信常駐は新規スクリプト 1 本（`claude-notify-daemon` に相乗りしない）

`claude-notify-daemon` は案1（HTTP 受信）専用で、`telegram` モードでは不要。Windows では ntfy 購読を daemon に内包しているが、Telegram 受信を同じ場所に入れると「案1 を使わないのに daemon を常駐させる」ことになる。よって `claude-notify-telegram-bot` を独立させ、`claude-notify-ntfy-sub` と同じ「未設定なら休眠して exit 0」の作法に揃える。LaunchAgent / Startup VBS の生成コードは `claude-notify-daemon` と重複するが、単体で完結するスクリプトという既存方針（各スクリプトが自己完結）を優先する。

Windows の停止処理は PID ファイル方式にする。既存 `claude-notify-daemon uninstall` は `taskkill /F /IM pythonw.exe` で全 `pythonw` を落とすため、新規スクリプトで同じことをすると相手を巻き込む。

### D7: 受信側は「起動時バックログ破棄 + `offset` 永続化 + 鮮度フィルタ」

スリープ復帰時に溜まった更新を全部読み上げると数分間喋り続ける。`offset` を `~/.local/state/claude-notify/telegram-offset` に永続化し、`date` が `CLAUDE_TELEGRAM_MAX_AGE`（既定 180 秒）より古いものは破棄する。発話は単一ワーカーで逐次実行（VOICEVOX に同時リクエストすると片方が失敗して `say` に落ちる既知問題があるため）。

### D8: 発話呼び出しには `CLAUDE_NOTIFY_MODE=voice` を明示する

受信側マシン自身の `config.env` が `telegram` だった場合、受信常駐が素朴に `claude-notify` を呼ぶと Telegram へ再送してループする。受信常駐は必ず `CLAUDE_NOTIFY_MODE=voice` を環境に入れて呼ぶ（D4 の環境変数優先と対になる設計）。

## Risks / Trade-offs

- **[最大リスク] チャンネル自動転送が受信 Bot に届かない可能性** → 実装着手前に curl だけで実機検証する（tasks 1.x）。成立しなければ案 B（Telethon 受信）へ差し替える。設計上、送信側の仕様（D3/D4/D5）と受信側の受理条件以外は共通なので、差し替え範囲は受信常駐 1 本に閉じる。
- **既定変更で既存端末の経路が切り替わる** → 未配線端末は `voice` へフォールバックするため無音にはならない。ただし「Telegram を配線した端末は以後ローカルで喋らなくなる」ので、README に `mode = "voice"` での固定手順とロールバック手順を明記する。
- **通知内容が Telegram のサーバを経由する** → 本文はリポジトリ名・ホスト名・セッション ID 先頭 8 文字・固定文言のみに限定（`telegram-notify-send` の要件）。プロンプトやツール出力は送らない。それでも「どのリポジトリでいつ作業したか」は Telegram 上に残る。既定が `telegram` である以上これは全端末に及ぶため、README のセキュリティ節で明示し、嫌な端末は `mode = "voice"` で opt-out できるようにする。
- **送信 Bot トークンをリモートにも置く** → 権限はチャンネル投稿のみ。受信 Bot トークンは手元だけに置き、漏洩範囲を分離する（D2）。チャンネルは非公開にする。
- **フック終端が最大 5 秒ブロックする**（`CLAUDE_TELEGRAM_TIMEOUT`） → 既存の案1 経路（4 秒）と同程度。回線不調時の体感悪化が許容できなければ、この値を下げるか将来的に非同期送信へ変更する。
- **同一受信トークンの二重ポーリングで 409** → マシンごとに受信 Bot を分ける運用をドキュメント化し、常駐側は 409 を検知したらバックオフして警告を残す。
- **Telegram 障害・オフライン時は無音**（ベルのみ） → 発話は本質的に「あると便利」な通知なので許容。恒久的に届かない環境では `voice` + 案1 に戻す。
- **重複実装（LaunchAgent/VBS 生成が daemon と二重）** → 保守コスト増を受け入れる（D6）。将来 3 本目が必要になったら共通モジュール化を検討。

## Migration Plan

1. **実機検証（実装前）**: BotFather で送信 Bot・受信 Bot を作成、非公開チャンネルとディスカッショングループを作成して連携、送信 Bot をチャンネル管理者、受信 Bot をグループへ（プライバシーモード無効）。curl で `sendMessage`（チャンネル宛）→ `getUpdates`（受信 Bot）を叩き、`is_automatic_forward` / `sender_chat` 付きで取得できることを確認する。
2. 失敗した場合は design を更新し、受信側を案 B（Telethon）に差し替える。送信側仕様と設定キーはそのまま流用する。
3. 実装は「設定 → 送信側 → 受信側 → setup 結線 → ドキュメント」の順。各段階で `voice` モードの回帰（Mac ローカル発話、devcontainer の案1）を確認する。
4. 展開は「手元マシンに受信常駐を入れる → 各端末の `chezmoi.toml` に送信トークンとチャット ID を入れて `chezmoi apply`」の順。`mode` は既定 `telegram` なので通常は書かない。ロールバックは `mode = "voice"` を書いて `chezmoi apply`（受信常駐は残っていても、送信が止まれば発話しない）。常駐を消すなら `claude-notify-telegram-bot uninstall`。
5. 既存端末は `mode` 未設定でも `telegram` になる。トークン未投入の間は `voice` へフォールバックするため無音にはならず、配線した端末から順に Telegram 経路へ移る（段階移行が可能）。

## Open Questions

- 受信 Bot に「任意テキストを喋らせる」「`/mute` で一時停止」を持たせるか（今回は Non-Goal。マーカー判定を通らない投稿は無視する設計なので、後から追加しても既存動作と衝突しない）。
- `telegram` モードでの nag を将来復活させる場合、繰り返しをリモート側で行うか（チャットが汚れる）受信側で行うか（cancel/resolve プロトコルが必要）。今回は無効で確定。
- スマホ通知の静音化（`disable_notification`）を `kind=done` だけに適用するか。初期実装では両方とも通知あり。
- 受信常駐を Linux デスクトップにも広げるか（現状は macOS / Windows のみ）。
