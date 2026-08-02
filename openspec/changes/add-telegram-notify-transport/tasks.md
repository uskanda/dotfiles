## 1. 実機検証（実装着手の前提）

- [ ] 1.1 BotFather で送信 Bot と受信 Bot を作成し、受信 Bot は `/setprivacy` を Disable にする
- [ ] 1.2 非公開チャンネルとディスカッショングループを作成して連携し、送信 Bot をチャンネル管理者、受信 Bot をグループに追加する
- [ ] 1.3 `getUpdates` でチャンネル ID（`-100…`）とグループ ID を確認し、値を控える
- [ ] 1.4 curl で送信 Bot からチャンネルへ 2 行のテストメッセージを `sendMessage`（`parse_mode` なし）して投稿できることを確認する
- [ ] 1.5 受信 Bot の `getUpdates` で 1.4 の投稿が `chat.id`=グループ / `sender_chat.id`=チャンネル / `is_automatic_forward`=true として取得できることを確認する（**ここが失敗したら design.md の案 B（Telethon 受信）へ差し替えてから 3 章を再設計**）
- [ ] 1.6 検証結果（取得できた JSON の要点、採用案 A/B の確定）を design.md の Migration Plan に追記する

## 2. 設定とモード分岐（送信側）

- [ ] 2.1 `dot_config/claude-notify/config.env.tmpl` に `CLAUDE_NOTIFY_MODE`（既定 `telegram`）/ `CLAUDE_TELEGRAM_BOT_TOKEN` / `CLAUDE_TELEGRAM_CHAT_ID` / `CLAUDE_TELEGRAM_TIMEOUT` を追加し、すべて `${VAR:-<chezmoi値>}` 形式で出力して環境変数が優先されるようにする
- [ ] 2.2 同ファイルのヘッダコメントに `[data.claudeNotify]` の新キー（`mode` / `telegramBotToken` / `telegramChatId` ほか）の書き方を追記する
- [ ] 2.3 `executable_claude-notify` に `notify_via_telegram()` を追加する（`sendMessage`、プレーンテキスト、`--max-time $CLAUDE_TELEGRAM_TIMEOUT`、単発試行）
- [ ] 2.4 `executable_claude-notify` の先頭でモードを解決し（既定 `telegram`、不正値は警告して既定扱い）、`telegram` のときは OS 分岐に入る前に送信して終了する経路を作る。ローカル発話は一切呼ばない
- [ ] 2.5 `telegram` モードで送信が失敗したときは `local_fallback`（ベル）のみ実行し、終了コード 0 で終わることを保証する
- [ ] 2.6 `telegram` モードでトークンまたはチャット ID が空のときは、警告 1 行の後に `voice` 経路へフォールバックする（既定モード変更で未配線端末が無音にならないようにする）
- [ ] 2.7 メッセージ本文を組み立てる（1 行目 = 絵文字 + 発話文、2 行目 = `#claude_notify kind=… host=… repo=… sid=…`、全体 4096 文字未満に切り詰め）。`kind` / `repo` / `sid` は `claude-notify-hook` から環境変数で受け渡す
- [ ] 2.8 `executable_claude-notify-hook` から `kind`（done/confirm）・`repo`・`sid` を `claude-notify` へ渡す（発話文の生成箇所は変えない）
- [ ] 2.9 `executable_claude-notify-nag` を `telegram` モードでは「grace 後 1 回だけ実行して終了」に分岐させる（`stop` が grace 中の 1 回目を取り消せることは維持）

## 3. 受信常駐（手元 macOS / Windows）

- [ ] 3.1 `dot_local/bin/executable_claude-notify-telegram-bot`（Python 3 標準ライブラリのみ）を新規作成し、`run` / `install` / `uninstall` の骨格と `config.env` 読み込み（既存環境変数を上書きしない）を実装する
- [ ] 3.2 未設定（受信トークンまたはリレー先チャット ID が空）なら 1 行出力して exit 0 する休眠挙動を実装する
- [ ] 3.3 `getUpdates` の長ポーリング（`timeout=50`、`allowed_updates=["message"]`）と指数バックオフ再接続（5→60 秒上限）、HTTP 409 の警告ログを実装する
- [ ] 3.4 受理条件（`chat.id` 一致 / `sender_chat.id` 一致または `is_automatic_forward` / `#claude_notify` マーカー必須）を実装し、非該当は黙って無視する
- [ ] 3.5 起動時のバックログ破棄、`offset` の永続化（`~/.local/state/claude-notify/telegram-offset`）、`CLAUDE_TELEGRAM_MAX_AGE`（既定 180 秒）超過の破棄を実装する
- [ ] 3.6 発話テキストの整形（マーカー行除去、先頭絵文字・記号除去、空白畳み込み、200 文字切り詰め）を実装する
- [ ] 3.7 発話呼び出しを実装する（macOS: `claude-notify` を `CLAUDE_NOTIFY_MODE=voice` 付きで、Windows: `claude-notify.ps1 -B64`）。単一ワーカーで逐次再生し、同時発話が重ならないようにする
- [ ] 3.8 macOS の LaunchAgent（`com.claude.notify-telegram-bot`、`RunAtLoad`/`KeepAlive`、`~/Library/Logs/claude-notify-telegram-bot.log`）の install/uninstall を実装する
- [ ] 3.9 Windows のスタートアップ VBS（`pythonw` 隠し起動）の install/uninstall を実装する。停止は PID ファイル方式にし、他の `pythonw.exe` を巻き込まないようにする

## 4. セットアップ結線

- [ ] 4.1 `setup` に `INSTALL_TELEGRAM_BOT=1` の opt-in 分岐を追加し、macOS で `claude-notify-telegram-bot install` を実行する（既定はスキップメッセージ）
- [ ] 4.2 `setup.ps1` に `-TelegramBot` スイッチ（および `INSTALL_TELEGRAM_BOT=1`）を追加し、`claude-notify-telegram-bot install` を実行する
- [ ] 4.3 `.chezmoiignore` に `openspec` を追加し、変更管理ディレクトリが `$HOME` へ配布されないようにする

## 5. 検証

- [ ] 5.1 `bash -n` で bash スクリプト、`python3 -m py_compile` で受信常駐の構文チェックを通す
- [ ] 5.2 `chezmoi diff` で `config.env` の出力差分を確認し、`mode` 未記述端末の出力が `telegram` になること、`mode = "voice"` を書いた端末は `voice` になることを確認する
- [ ] 5.3 手元 Mac で `CLAUDE_NOTIFY_MODE=voice` の回帰確認（VOICEVOX 発話、`say` フォールバック、nag の 10 分繰り返し）
- [ ] 5.4 devcontainer から `CLAUDE_NOTIFY_MODE=telegram` で completion / confirmation を発生させ、Telegram 到達 → 手元 Mac の発話までを確認する
- [ ] 5.5 SSH 先から同様に確認する（ポート転送設定なしで届くこと）
- [ ] 5.6 Windows を受信側にして同様に確認する（VOICEVOX 不在時に SAPI5 へ落ちること）
- [ ] 5.7 異常系: トークン空（＝`voice` へフォールバックして鳴る）/ ネットワーク切断（ベルのみ）/ 3 時間スリープ後の復帰（古い通知を読み上げない）/ 同一トークン二重起動（409）を確認する
- [ ] 5.8 受信側マシンの `config.env` が `telegram` でも再送ループが起きないことを確認する

## 6. ドキュメント

- [ ] 6.1 README に「Telegram 経由の通知（任意）」節を追加する（構成図、Bot 2 個・チャンネル・連携グループの作成手順、ID の取り方）
- [ ] 6.2 `[data.claudeNotify]` の新キー一覧、既定が `telegram` である旨、`mode = "voice"` で端末単位に opt-out / ロールバックする手順を README に追記する
- [ ] 6.3 トラブルシュート（何も喋らない / 409 / 古い通知が読まれる / プライバシーモード有効のまま / チャンネルとグループの ID を混同）を README に追記する
- [ ] 6.4 セキュリティ注意（送信 Bot と受信 Bot の権限分離、非公開チャンネル、Telegram に残る情報の範囲）を README に追記する
