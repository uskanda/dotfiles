---
name: set-workspace-theme
description: VS Code で今開いている workspace の window.title と workbench.colorTheme を対話的に設定する。アイコン付きタイトルと、稼働中の他ウィンドウと色相が離れた見分けやすいテーマを提案してから書き込む。Use when the user wants a per-workspace VS Code window title or color theme, wants to tell multiple VS Code windows apart at a glance, or asks to color-code / label this workspace. Keywords: window.title, workbench.colorTheme, workspace settings, .code-workspace, per-project theme, ウィンドウ 見分け, タイトル アイコン, テーマ 変更。
allowed-tools: Bash, Read, Edit, Write, Glob, Grep, AskUserQuestion
---

# set-workspace-theme

VS Code のウィンドウを何枚も開いていると、どれがどの workspace か分からなくなる。
このスキルは今開いている workspace に対して `window.title`（アイコン付き）と
`workbench.colorTheme`（他ウィンドウと色相が離れたもの）を設定し、一目で見分けられるようにする。

**必ず「提案 → ユーザー応答 → 反映」の順で進める。** ユーザーが提案と違う値を答えたら、
その値をそのまま採用する。黙って書き込まない。

## 前提

書き込み先は user settings ではなく **workspace 側**。対象の形によって場所が変わる。

| workspace の形 | 書き込み先 | 置き場所 |
| --- | --- | --- |
| 単一フォルダ | `<workspace>/.vscode/settings.json` | トップレベル |
| multi-root | `<name>.code-workspace` | `settings` オブジェクトの中 |

> ⚠️ **multi-root のとき、各フォルダの `.vscode/settings.json` に書いても無視される。**
> `window.title` と `workbench.colorTheme` はどちらも window スコープの設定で、multi-root
> ではフォルダ単位の設定に置けない（window スコープの設定を受け付けるのは user settings と
> `.code-workspace` だけ）。必ず `.code-workspace` 側へ書くこと。

> ⚠️ **`workbench.colorTheme` の値は表示ラベルではなくテーマの `id`。** 日本語言語パックを
> 入れているとラベルだけが翻訳される（`Dark Modern` → `ダーク モダン`）ため、画面に見えている
> 名前で書くと黙って効かない。手順 1 のスクリプトが出す `settingsId` をそのまま使う。

保存すれば即座に反映される（リロード不要）。ただしワークスペースの信頼が**制限モード**だと
`workbench.colorTheme` は適用されない。

## 手順

### 1. 環境を集める

```bash
python3 ~/.claude/skills/set-workspace-theme/scripts/vscode-workspace-env.py
```

対象を明示したいときは workspace のパスを引数に渡す（既定は cwd）。JSON で返る:

| キー | 中身 |
| --- | --- |
| `target` | 書き込み先。`kind`（`folder` / `workspaceFile`）、`settingsFile`、`settingsKeyPath`、現在の `currentWindowTitle` / `currentColorTheme` |
| `otherWindows` | 今開いている他のウィンドウと、それぞれの実効テーマ |
| `takenColors` | 他ウィンドウで既に使われている背景色（`hue` / `neutral`） |
| `suggestions` | 使用中の色相から遠い順に並べたテーマ候補（背景に不向きなものは除外済み） |
| `themes` | インストール済み全テーマ（`settingsId` / `bg` / `hue` / `chroma` / `luma` / `unsuitable`） |

`target` に `note` が付いていたら、開いているウィンドウ一覧に一致するものが無かったということ
（ウィンドウを開いた直後は VS Code の状態ファイルが追いついていない）。単一フォルダとみなして
話を進めるが、書き込む前に対象パスをユーザーへ確認する。

`otherWindows` のうち `remote` が `ssh-remote+...` のものは、この端末から設定ファイルを読めない
（`settingsFile` が `null`）。その分は色の重複判定から漏れるので、候補が僅差なら一言添える。

### 2. workspace の性格をつかむ

アイコンと名前の根拠にする。README / CLAUDE.md / `package.json` / `git remote -v` あたりを軽く見て、
「何のための workspace か」を一言で言えるようにする。既に `window.title` が設定されていれば
それを土台にする（全取り替えより、アイコンを足す案のほうが受け入れられやすい）。

### 3. window.title の案を作る

- **原則としてアイコン（絵文字）を先頭に 1 つ**置き、半角スペースを空けて名前を続ける。
  タブバーや Alt+Tab で判別できることが目的なので、内容が想像できる絵文字を選ぶ。
  例: `⚙️ dotfiles` / `📦 <ライブラリ名>` / `🧪 検証` / `🚀 本番` / `📝 ドキュメント`
- 既定の形は `<アイコン> <名前>${separator}${activeEditorShort}`。
  編集中のファイル名が出つつ、先頭のアイコンは常に残る。
- ユーザーが**意図的にアイコンを省いた**場合（「アイコンなしで」「絵文字は要らない」等）は
  それに従い、アイコンを足し直さない。
- 使える主な変数: `${activeEditorShort}` `${activeEditorMedium}` `${rootName}` `${folderName}`
  `${separator}` `${dirty}` `${remoteName}` `${appName}`。
  空の変数は前後の `${separator}` ごと消えるので、並べてもセパレータだけが残る心配はない。

### 4. workbench.colorTheme の案を作る

`suggestions` の先頭（稼働中の他ウィンドウの色相から最も離れたもの）を第一候補にする。判断材料:

- **`hueDistance`** — 使用中の色相との角度差。大きいほど被らない。`-1` は「他ウィンドウが既に
  無彩色テーマなので、これも無彩色で被る」の意味。
- **`unsuitable`** — 背景として不向きな理由（彩度が高すぎる / 明るすぎる / 暗すぎる）。
  空でないものは提案しない。`suggestions` は除外済みなので、`themes` から直接拾うときだけ注意。
- **`uiTheme`** — `vs-dark` / `vs`（明色）/ `hc-*`（ハイコントラスト）。現在の実効テーマと明暗の
  系統を合わせる。暗色で作業している相手にいきなり明色テーマを出さない。

> ⚠️ ウィンドウの見分けやすさを決めるのは**背景・タイトルバー・アクティビティバーの色**であって、
> シンタックスハイライトではない。`chroma` が小さいテーマ（Monokai や One Dark 系は背景が
> ほぼ灰色）は、構文色が鮮やかでもウィンドウの区別には効かない。`neutral` が `true` のものは
> 「色で見分ける」目的には向かないと考える。

`takenColors` が空なら、誰も明示指定していない（全ウィンドウが VS Code 既定テーマ）。
この場合は色の付いたテーマなら何でも被らないので、workspace の性格に合う色を選べばよい。

候補が尽きた場合（開いているウィンドウが多く、色相が埋まっている）は、無理に遠い色を
ひねり出さず「今開いている N 枚と完全に離すのは無理」と正直に伝え、いちばんマシな案を出す。

### 5. まとめて提案する

`AskUserQuestion` を **1 回**呼び、`window.title` と `workbench.colorTheme` の 2 問を同時に出す。

- 推奨案を各問の先頭に置き、ラベル末尾に `(推奨)` を付ける。
- テーマの選択肢はラベルを `settingsId` にし、`description` に背景色・色相・
  「他ウィンドウのどれと離れているか」を書く。ユーザーが色を想像できるようにする。
- ユーザーが「Other」で別の値を答えたらそれを採用する。テーマ名が返ってきたら `themes` に
  同じ `settingsId` があるか照合し、無ければ近いものを挙げて訊き直す。
  **未インストールのテーマ名を書いても VS Code は無言で無視する**ので、ここで必ず弾く。

### 6. 書き込む

`target.settingsFile` を編集する。存在しなければ `.vscode/` ごと作る。
既存ファイルはコメントや整形を壊さないよう `Edit` で最小差分にする（全書き換えはしない）。

`kind: "folder"` — トップレベルに 2 キー:

```json
{
  "window.title": "⚙️ dotfiles${separator}${activeEditorShort}",
  "workbench.colorTheme": "Solarized Dark"
}
```

`kind: "workspaceFile"` — `settings` の中に 2 キー（`settings` が無ければ `folders` の後に足す）:

```json
{
  "folders": [{ "path": "." }],
  "settings": {
    "window.title": "⚙️ dotfiles${separator}${activeEditorShort}",
    "workbench.colorTheme": "Solarized Dark"
  }
}
```

値は手順 3 / 4 で決めたものに置き換えること（上は形の例）。

### 7. 確認して報告

- 手順 1 のスクリプトを再実行し、`target.currentWindowTitle` / `currentColorTheme` が
  意図どおりになったことを確認する。
- ユーザーにはタイトルバーと配色が実際に変わったかを確認してもらう。変わっていなければ
  **制限モード** → **`settingsId` の綴り** → **multi-root なのにフォルダ側へ書いていないか**
  の順に疑う。
- ⚠️ 書き込み先がリポジトリ内の `.vscode/settings.json` だった場合、git の差分になる。
  コミットするかどうかはユーザーに確認する。勝手にコミットしない。
