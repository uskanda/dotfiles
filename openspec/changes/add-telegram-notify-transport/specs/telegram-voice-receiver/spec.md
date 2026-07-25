## ADDED Requirements

### Requirement: 受信常駐のライフサイクル
`claude-notify-telegram-bot` は `run` / `install` / `uninstall` のサブコマンドを持ち、`install` で手元マシンに常駐しなければならない（SHALL）。macOS では LaunchAgent（`com.claude.notify-telegram-bot`、`RunAtLoad` + `KeepAlive`、ログは `~/Library/Logs/claude-notify-telegram-bot.log`）、Windows ではスタートアップフォルダの VBS から `pythonw` を隠し起動する方式を用いなければならない（SHALL）。Python 3 標準ライブラリ以外の依存を追加してはならない（SHALL NOT）。

#### Scenario: macOS への常駐
- **WHEN** `claude-notify-telegram-bot install` を実行する
- **THEN** LaunchAgent が書き出されて即座に起動し、再ログイン後も自動復帰する

#### Scenario: Windows への常駐
- **WHEN** `python %USERPROFILE%\.local\bin\claude-notify-telegram-bot install` を実行する
- **THEN** スタートアップに VBS が置かれ、その場でも隠しプロセスとして起動する

#### Scenario: 未設定なら休眠する
- **WHEN** 受信用トークンまたはリレー先チャット ID が空の状態で `run` を実行する
- **THEN** 何もせず 1 行のメッセージを出して終了コード 0 で終了する（`claude-notify-ntfy-sub` と同じ休眠挙動）

#### Scenario: 停止は自分のプロセスだけ
- **WHEN** 他の Python 常駐（`claude-notify-daemon` 等）が動いている Windows で `uninstall` を実行する
- **THEN** 自身が記録した PID のプロセスのみが停止され、他の `pythonw.exe` は停止されない

### Requirement: Claude Code 由来メッセージだけを受理する
受信常駐は取得した更新のうち、次のすべてを満たすメッセージだけを発話対象としなければならない（SHALL）。(1) `chat.id` が `CLAUDE_TELEGRAM_RELAY_CHAT_ID`（連携ディスカッショングループ）と一致する、(2) `sender_chat.id` が `CLAUDE_TELEGRAM_SOURCE_CHAT_ID`（リレー用チャンネル）と一致する、または `is_automatic_forward` が真である、(3) 本文に `#claude_notify` で始まるマーカー行が含まれる。条件を満たさないメッセージは黙って無視しなければならない（SHALL）。

#### Scenario: 正規のリレーを発話する
- **WHEN** 送信 Bot がチャンネルへ投稿し、それが連携グループへ自動転送される
- **THEN** 受信常駐がその更新を受理し、1 行目を発話する

#### Scenario: 人間の雑談は発話しない
- **WHEN** 同じグループでユーザーが任意のテキストを投稿する
- **THEN** マーカー行が無いため無視され、発話は起こらない

#### Scenario: 別チャットからの混入を弾く
- **WHEN** マーカー行を含むメッセージが設定外のチャットから届く
- **THEN** `chat.id` 不一致で無視される

### Requirement: 発話は既存経路を再利用する
発話はマーカー行を除いた 1 行目のテキストを整形（先頭の絵文字・記号の除去、連続空白の畳み込み、200 文字への切り詰め）した上で、macOS では `claude-notify`（`CLAUDE_NOTIFY_MODE=voice` を明示指定）、Windows では `claude-notify.ps1 -B64 <base64(UTF-8)>` に渡さなければならない（SHALL）。受信常駐が `claude-notify` を `telegram` モードで呼び出して再送ループを作ってはならない（SHALL NOT）。同時に複数メッセージが届いた場合は逐次再生し、VOICEVOX への同時リクエストで音声が重ならないようにしなければならない（SHALL）。

#### Scenario: macOS で VOICEVOX が鳴る
- **WHEN** 受理したメッセージの 1 行目が `✅ dotfilesの作業が完了しました`
- **THEN** `dotfilesの作業が完了しました` が VOICEVOX（不在時は `say`）で読み上げられる

#### Scenario: 再送ループを起こさない
- **WHEN** 受信側マシンの `config.env` が `CLAUDE_NOTIFY_MODE=telegram` になっている
- **THEN** 発話呼び出しには `CLAUDE_NOTIFY_MODE=voice` が明示され、Telegram への再送信は発生しない

#### Scenario: 連続到着でも重ならない
- **WHEN** 2 通のメッセージがほぼ同時に届く
- **THEN** 1 通目の再生完了後に 2 通目が再生される

### Requirement: 鮮度と重複の制御
受信常駐は起動時に未処理分の滞留（バックログ）を破棄し、以後 `getUpdates` の `offset` を永続化して再起動後の重複発話を防がなければならない（SHALL）。`date` が `CLAUDE_TELEGRAM_MAX_AGE` 秒（既定 180）より古いメッセージは発話せず破棄しなければならない（SHALL）。

#### Scenario: スリープ復帰で溜まった通知を捨てる
- **WHEN** ノート PC を 3 時間スリープさせた後に復帰し、その間に 10 通の通知が溜まっている
- **THEN** いずれも `MAX_AGE` 超過として破棄され、連続発話は起こらない

#### Scenario: 再起動しても同じ通知を二度発話しない
- **WHEN** 1 通を発話した直後に常駐を再起動する
- **THEN** 永続化された `offset` により同じメッセージは再取得・再発話されない

### Requirement: 障害耐性と単一受信者
受信常駐は `getUpdates` の長ポーリング（`timeout` 50 秒程度）を用い、ネットワーク断・HTTP エラー時は指数バックオフ（初回 5 秒、上限 60 秒）で再接続を続けなければならない（SHALL）。HTTP 409（Conflict = 同一トークンで複数のポーラーが競合）を受けた場合は警告をログに出してバックオフしなければならない（SHALL）。同一の受信 Bot トークンで複数マシンが同時にポーリングしてはならない（SHALL NOT）。複数マシンで発話したい場合は受信 Bot をマシンごとに用意する。

#### Scenario: 回線断からの自動復帰
- **WHEN** Wi-Fi を 10 分切断し、その後復帰する
- **THEN** 常駐は落ちずにバックオフ再接続し、復帰後の新規メッセージを発話する

#### Scenario: トークン競合を検知できる
- **WHEN** 同じ受信トークンで 2 台がポーリングする
- **THEN** 409 が発生した側がログに警告を残し、無限に高頻度再試行しない
