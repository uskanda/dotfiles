## Why

Claude Code の Stop/Notification フックは現在「目の前のマシンで VOICEVOX を鳴らす」前提で作られている。SSH 先や devcontainer では自前のスピーカーが無いため、案1（Mac/Win の `claude-notify-daemon` に :50090 で POST）か案2（セルフホスト ntfy）でリレーしているが、案1 は環境ごとに経路設計（`host.docker.internal` / `RemoteForward` / LAN 公開 + 共有トークン）が必要で、案2 はサーバ運用が前提のため実質未構築。結果として「SSH/devcontainer では発話が届かない」状態が残っている。

Telegram Bot API を経路にすると、ポート転送も自前サーバも無しにリモートから手元へメッセージを届けられ、同時にスマホへの通知も得られる。手元の PC 側に「Claude Code 由来のメッセージを受けたら VOICEVOX で発話する」常駐を置けば、既存の発話品質（VOICEVOX、日本語、リポジトリ名の読み上げ）をそのまま維持できる。

## What Changes

- 通知経路を選ぶ設定 `CLAUDE_NOTIFY_MODE`（`voice` | `telegram`、既定 `voice`）を追加する。どちらか一方のみが動作し、既定は現行動作そのままで非破壊。
- `telegram` モードでは `claude-notify` はローカル発話を一切行わず、Telegram へ 1 通だけ送信する（送信本文の 1 行目が「発話される文」になる契約）。
- 新規常駐 `claude-notify-telegram-bot`（macOS / Windows）を追加する。Telegram を長ポーリングし、**Claude Code 由来と判定できたメッセージだけ**を既存の発話経路（`claude-notify` → VOICEVOX / `claude-notify.ps1` → VOICEVOX→SAPI5）に渡す。
- リレー構成は「送信 Bot が非公開チャンネルへ投稿 → Telegram が連携ディスカッショングループへ自動転送 → グループ内の受信 Bot が読む」を採用する（Bot は他 Bot / 自分自身の送信メッセージを `getUpdates` で受信できないため、単一 Bot の往復では成立しない）。送信用と受信用で **Bot を 2 つに分離**し、リモートには「チャンネルへ投稿する権限しかないトークン」だけを置く。
- `telegram` モードでは nag（10 分毎の再催促）を無効化する。ただし turn 終了時の「確認をお願いします」を抑制する grace 遅延（既定 3 秒）は維持し、Telegram への無駄な 1 通を防ぐ。
- `setup` / `setup.ps1` に opt-in の受信常駐インストール（`INSTALL_TELEGRAM_BOT=1` / `-TelegramBot`）、`config.env.tmpl` に設定キー、README に構成図・手順・トラブルシュートを追加する。
- 既存の `voice` モード（macOS `say` フォールバック、Windows interop、案1 デーモン、案2 ntfy）はコードも既定値も変更しない。

## Capabilities

### New Capabilities
- `notify-transport-selection`: 通知経路（`voice` / `telegram`）の選択と、設定値の解決順序・既定値・不正値の扱い。
- `telegram-notify-send`: 送信側（Claude Code が動くマシン）の Telegram 送信仕様。メッセージ書式、送信先、タイムアウト、失敗時フォールバック、nag の扱い。
- `telegram-voice-receiver`: 受信側（手元の macOS / Windows）常駐の仕様。受理条件（Claude Code 由来の判定）、発話、鮮度・重複制御、常駐ライフサイクル。

### Modified Capabilities
（なし。`openspec/specs/` は本変更で初期化されたばかりで、既存仕様ファイルは存在しない。既存 `voice` 経路の振る舞いは `notify-transport-selection` の回帰要件として記述する。）

## Impact

- `dot_local/bin/executable_claude-notify`: モード分岐と `notify_via_telegram()` の追加（`voice` 経路のロジックは不変）。
- `dot_local/bin/executable_claude-notify-nag`: `telegram` モードでは grace 後 1 回だけ送って終了（繰り返さない）。
- `dot_local/bin/executable_claude-notify-telegram-bot`: **新規**。Python 3 標準ライブラリのみ、`run` / `install` / `uninstall`（macOS: LaunchAgent、Windows: Startup VBS）。
- `dot_config/claude-notify/config.env.tmpl`: `CLAUDE_NOTIFY_MODE` と Telegram 用キーを追加（環境変数が設定ファイルより優先されるよう `${VAR:-...}` 形式で出力）。
- `setup` / `setup.ps1`: 受信常駐の opt-in インストール。
- `README.md`: Telegram 経路の節を追加。
- `.chezmoiignore`: `openspec`（本変更の管理ディレクトリを `$HOME` に配布しない）。
- 無改修: `executable_claude-notify-hook`（`claude-notify` / `claude-notify-nag` を呼ぶだけ）、`claude-notify.ps1`（受信側がそのまま再利用）、`claude-notify-daemon`、`claude-notify-ntfy-sub`。
- 外部依存: Telegram Bot API（HTTPS 到達性）。追加パッケージ（telethon 等）は採用案では不要。
