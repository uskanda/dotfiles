## ADDED Requirements

### Requirement: 通知経路をモードで択一選択する
`claude-notify` は設定値 `CLAUDE_NOTIFY_MODE` に従い、`telegram`（既定）と `voice` のいずれか一方の経路だけを使用しなければならない（SHALL）。両方を同時に実行してはならない（SHALL NOT）。未設定時は `telegram` として扱う（SHALL）。ただし Telegram の送信設定が未投入の端末が無音になるのを避けるため、`telegram` かつ送信設定が空の場合のみ `voice` 経路へフォールバックしなければならない（SHALL、詳細は `telegram-notify-send`）。

#### Scenario: 未設定なら telegram
- **WHEN** `CLAUDE_NOTIFY_MODE` が設定ファイル・環境変数のいずれにも無く、Telegram の送信設定が投入済みの端末で `claude-notify "テスト"` を実行する
- **THEN** `telegram` 経路として Telegram へ 1 通だけ送信され、VOICEVOX / `say` / SAPI5 / `afplay` / `paplay` は一切呼ばれない

#### Scenario: telegram モードではローカル発話しない
- **WHEN** `CLAUDE_NOTIFY_MODE=telegram` で `claude-notify "テスト"` を実行する
- **THEN** Telegram へ 1 通だけ送信され、VOICEVOX / `say` / SAPI5 / `afplay` / `paplay` は一切呼ばれない

#### Scenario: voice を明示した端末は従来経路
- **WHEN** `CLAUDE_NOTIFY_MODE=voice` で `claude-notify "テスト"` を実行する
- **THEN** 現行と同じ `voice` 経路（macOS: VOICEVOX→`say` / Windows: `claude-notify.ps1` / container・SSH: 案1→案2→ベル）で処理され、Telegram へは 1 通も送信されない

#### Scenario: 不正値は既定へフォールバック
- **WHEN** `CLAUDE_NOTIFY_MODE=telegramm`（綴り誤り）で `claude-notify "テスト"` を実行する
- **THEN** 既定の `telegram` として処理され、警告を stderr に 1 行出力し、終了コードは 0 になる

### Requirement: 設定値の解決順序
モードおよび Telegram 関連の設定値は「環境変数 > `~/.config/claude-notify/config.env` > スクリプト既定値」の順で解決されなければならない（SHALL）。`config.env` は環境変数を上書きしてはならない（SHALL NOT）。

#### Scenario: 環境変数が設定ファイルに勝つ
- **WHEN** `config.env` に `CLAUDE_NOTIFY_MODE="telegram"` が入っている端末で `CLAUDE_NOTIFY_MODE=voice claude-notify "テスト"` を実行する
- **THEN** `voice` 経路で処理される（一時的な切り戻し・デバッグが可能）

#### Scenario: 端末ごとの上書きは chezmoi データで行う
- **WHEN** `~/.config/chezmoi/chezmoi.toml` に `[data.claudeNotify] mode = "voice"` を書いて `chezmoi apply` する
- **THEN** `~/.config/claude-notify/config.env` に `CLAUDE_NOTIFY_MODE` が `voice` として出力され、その端末だけ従来経路に固定される

#### Scenario: chezmoi データ未記述なら telegram
- **WHEN** `[data.claudeNotify] mode` を書かずに `chezmoi apply` する
- **THEN** `config.env` の `CLAUDE_NOTIFY_MODE` は既定値 `telegram` として出力される

### Requirement: voice モードの既存動作を維持する
本変更は `voice` モードの経路選択ロジック（macOS / native Windows / WSL2 interop / container・SSH の案1→案2→ローカルフォールバック）を変更してはならない（SHALL NOT）。

#### Scenario: devcontainer での voice モード回帰
- **WHEN** devcontainer 内（`/.dockerenv` あり）で `CLAUDE_NOTIFY_MODE=voice` として `claude-notify "テスト"` を実行する
- **THEN** 案1（`http://host.docker.internal:50090/notify`）→案2（ntfy）→ローカルフォールバック（ベル）の順に、変更前と同じ順序で試行される

#### Scenario: nag の grace 抑制はモードに依らず有効
- **WHEN** turn 終了時に Notification と Stop がほぼ同時に発火する
- **THEN** grace（既定 3 秒）内に `claude-notify-nag stop` が届いた「確認をお願いします」は、`voice` / `telegram` いずれのモードでも発話も送信もされない
