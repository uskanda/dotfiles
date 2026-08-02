## ADDED Requirements

### Requirement: Telegram メッセージの書式
`telegram` モードの送信本文は 2 行構成でなければならない（SHALL）。1 行目は「受信側が発話する文」、2 行目は機械可読なマーカー行とする。マーカー行は `#claude_notify` で始まり、空白区切りの `key=value` を並べる。

```
✅ dotfiles の作業が完了しました
#claude_notify kind=done host=devbox repo=dotfiles sid=ab12cd34
```

`kind` は `done`（作業完了）または `confirm`（確認要求）、`host` は送信元ホスト名、`repo` はフックの cwd の git トップレベル名（無ければ省略）、`sid` はフック JSON の `session_id` 先頭 8 文字（無ければ省略）とする。1 行目の先頭には `kind` に応じた絵文字（`done`→`✅` / `confirm`→`🔔`）を付けてもよい（MAY）。本文全体は 4096 文字未満に切り詰めなければならない（SHALL）。

#### Scenario: 完了通知の送信
- **WHEN** `dotfiles` リポジトリで turn が終了し、`claude-notify-hook done` が `claude-notify "dotfilesの作業が完了しました"` を呼ぶ
- **THEN** 1 行目が `✅ dotfilesの作業が完了しました`、2 行目が `#claude_notify kind=done host=<hostname> repo=dotfiles sid=<8桁>` のメッセージが 1 通送信される

#### Scenario: 確認要求の送信
- **WHEN** 権限プロンプト等で `claude-notify-hook notification` が発火し、grace 経過後に確認メッセージが送られる
- **THEN** 1 行目が `🔔 dotfilesの確認をお願いします`、2 行目のマーカー行に `kind=confirm` を含むメッセージが 1 通送信される

#### Scenario: git 管理外ディレクトリ
- **WHEN** git リポジトリでない cwd から通知が発生する
- **THEN** 1 行目はリポジトリ名を含まない既存の文言（例 `✅ 作業が完了しました`）となり、マーカー行から `repo=` が省略される

### Requirement: 送信手段と宛先
送信は Telegram Bot API の `sendMessage`（`https://api.telegram.org/bot<token>/sendMessage`）へ、`CLAUDE_TELEGRAM_BOT_TOKEN` と `CLAUDE_TELEGRAM_CHAT_ID`（リレー用チャンネル）を用いて行わなければならない（SHALL）。本文は書式崩れによる送信失敗を避けるためプレーンテキストで送り、`parse_mode` を指定してはならない（SHALL NOT）。1 回の通知につき送信は 1 回のみ試行し、タイムアウトは `CLAUDE_TELEGRAM_TIMEOUT` 秒（既定 5）を超えてはならない（SHALL NOT）。

#### Scenario: 通常送信
- **WHEN** トークンとチャット ID が設定済みで、ネットワークが正常
- **THEN** `sendMessage` が 1 回だけ呼ばれ、フックは 5 秒以内に終了する

#### Scenario: フックを遅延させない
- **WHEN** `api.telegram.org` へ到達できずタイムアウトする
- **THEN** `CLAUDE_TELEGRAM_TIMEOUT` 秒で打ち切られ、リトライは行われない

### Requirement: 送信失敗時のフォールバック
送信設定が投入済みで送信が失敗した場合、`claude-notify` はローカルフォールバック（端末ベル、可能なら通知音）のみを行い、`voice` 経路（VOICEVOX / say / 案1 / 案2）へ切り替えてはならない（SHALL NOT）。フックを壊さないため終了コード 0 で終了しなければならない（SHALL）。

#### Scenario: 送信失敗
- **WHEN** `telegram` モードでネットワークが切れている状態で通知が発生する
- **THEN** ベルのみが鳴り、終了コードは 0、Claude Code の turn は妨げられない

#### Scenario: API がエラーを返す
- **WHEN** チャット ID 誤りなどで `sendMessage` が 400 を返す
- **THEN** リトライせずベルのみで終了コード 0 になり、stderr に 1 行の警告が残る

### Requirement: 未設定端末は voice へフォールバックする
既定モードが `telegram` であるため、`CLAUDE_TELEGRAM_BOT_TOKEN` または `CLAUDE_TELEGRAM_CHAT_ID` が空の端末（＝まだ Telegram を配線していない端末）では、`claude-notify` は stderr に 1 行の警告を出した上で `voice` 経路へフォールバックしなければならない（SHALL）。この場合も終了コードは 0 でなければならない（SHALL）。

#### Scenario: 未配線の Mac
- **WHEN** `CLAUDE_NOTIFY_MODE` 未設定（＝既定 `telegram`）でトークンが空の Mac で通知が発生する
- **THEN** 送信は試みられず、警告 1 行の後に従来どおり VOICEVOX（不在時は `say`）で発話される

#### Scenario: 未配線の devcontainer
- **WHEN** 同じ状態の devcontainer で通知が発生する
- **THEN** `voice` 経路として案1（デーモン）→案2（ntfy）→ベルの順に試行される

#### Scenario: 設定済みなら択一を守る
- **WHEN** トークンとチャット ID が投入済みの端末で通知が発生する
- **THEN** Telegram 送信のみが行われ、送信の成否に依らず `voice` 経路は実行されない

### Requirement: telegram モードでは nag を繰り返さない
`telegram` モードでは `claude-notify-nag start` は grace（`CLAUDE_NAG_GRACE`、既定 3 秒）後に 1 回だけ送信して終了しなければならない（SHALL）。`CLAUDE_NAG_INTERVAL` による繰り返し送信を行ってはならない（SHALL NOT）。`claude-notify-nag stop` は grace 中の 1 回目を取り消せなければならない（SHALL）。

#### Scenario: 確認要求が 1 通で止まる
- **WHEN** `telegram` モードで権限プロンプトが表示され、ユーザーが 30 分応答しない
- **THEN** Telegram に送られる確認メッセージは 1 通だけで、10 分毎の再送は発生しない

#### Scenario: turn 終了時の抑制
- **WHEN** turn 終了に伴う Notification の直後（grace 内）に Stop フックが `nag stop` を呼ぶ
- **THEN** 「確認をお願いします」は送信されず、`kind=done` のメッセージのみが送信される

#### Scenario: voice モードの nag は不変
- **WHEN** `CLAUDE_NOTIFY_MODE=voice` で権限プロンプトが表示され、応答しないまま放置する
- **THEN** 従来どおり `CLAUDE_NAG_INTERVAL`（既定 600 秒）毎にローカルで再発話される

### Requirement: 送信内容を通知文に限定する
送信本文には既存の発話文（固定文言＋リポジトリ名）とマーカー行のメタデータ（ホスト名・リポジトリ名・セッション ID 先頭 8 文字・種別）以外を含めてはならない（SHALL NOT）。プロンプト本文、ツール出力、ファイルパス、フック JSON の生データを送信してはならない（SHALL NOT）。

#### Scenario: 会話内容が外部へ出ない
- **WHEN** 秘匿情報を含むプロンプトを扱っている session で通知が発生する
- **THEN** 送信されるのは固定文言・リポジトリ名・ホスト名・セッション ID 先頭 8 文字のみで、会話内容は含まれない
