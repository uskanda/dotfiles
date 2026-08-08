---
name: push
description: 現在のブランチを origin へ push してください。未コミットの変更がある場合、push 先が protected ブランチならユーザー確認のうえ新規ブランチを作成してから、protected でなければそのまま、/commit スキルでコミットしてから push します。
allowed-tools: Bash, Read, Grep, Glob, AskUserQuestion, Skill
---

# 現在のブランチを origin へ push

現在のブランチを `origin` へ push してください。未コミットの変更がある場合は、push 先ブランチが protected かどうかで挙動を変える。

- **protected** → ユーザーに確認 → 新規ブランチを作成 → `/commit` でコミット → 新規ブランチを push
- **protected でない** → `/commit` でコミット → 現在のブランチを push
- **未コミットの変更なし** → そのまま push

## 手順

### 1. 前提確認

- `git rev-parse --show-toplevel` で git リポジトリ内であることを確認する
- `git remote get-url origin` で `origin` が存在することを確認する
- どちらか失敗したら**中止**してユーザーに報告する
- `git branch --show-current` で現在のブランチ名を取得する（detached HEAD なら中止）

### 2. 未コミットの変更を確認

- `git status --porcelain` で未コミットの変更（追跡外ファイルを含む）の有無を判定する
- **変更が無い場合** → 手順 5（push）へ進む
- **変更がある場合** → 手順 3 へ進む

### 3. push 先ブランチが protected か判定する

判定は次の優先順位で行う。判定に使った根拠（プロジェクト指示 / API / ブランチ名フォールバック）を、後の報告で必ず明示すること。

**優先度 1: プロジェクト指示の明記を最優先する**

`CLAUDE.md`（およびリポジトリ内の同等のプロジェクト指示）に、対象ブランチの保護状況が明記されている場合は**それに従い、API 判定もフォールバックも行わない**。

- 例: 「`master` にブランチ保護はかかっておらず直接 push してよい」→ **not-protected** と確定して手順 4-B へ
- 例: 「`main` は保護されているので直接 push しないこと」→ **protected** と確定して手順 4-A へ

これはヒューリスティックによる誤判定（`master` などの名前を機械的に protected 扱いしてしまう）を防ぐためで、明記がある限りユーザーへの確認も不要。

**優先度 2: ホストの API で判定する**

`git remote get-url origin` のホスト名で判定方法を切り替える。

**GitHub の場合**（`gh` が認証済みであること）:

```
gh api "repos/$(gh repo view --json nameWithOwner -q .nameWithOwner)/branches/<BRANCH>" --jq .protected
```

`true` なら protected。この `protected` フィールドはブランチ保護ルール・ルールセットの双方を反映する。

**GitLab の場合**（`glab` が認証済みであること）:

保護ルールはワイルドカード（`release/*` など）で登録されていることがあるため、
単一ブランチを名前で引かず、**一覧を取得してグロブ照合**する:

```
PROJ=$(git remote get-url origin | sed -E 's#^(https?://[^/]+/|git@[^:]+:|ssh://git@[^/]+/)##; s#\.git$##' | sed 's#/#%2F#g')
glab api "projects/$PROJ/protected_branches" --paginate | python3 -c "
import sys,json,fnmatch
b='<BRANCH>'
rules=[r['name'] for r in json.load(sys.stdin)]
print('protected' if any(fnmatch.fnmatch(b,n) for n in rules) else 'not-protected')
"
```

**優先度 3: API で判定できない場合のフォールバック**

プロジェクト指示に明記がなく、かつ `gh` / `glab` が未認証、ネットワーク不通、ホストが GitHub/GitLab のいずれでもない、など API 判定にも失敗したときは、**ブランチ名で判定する**:

- `main` / `master` / `develop` / `qa` / `staging` / `production` / `release/*` に一致 → protected とみなす
- それ以外 → protected でないとみなす

フォールバックを使った場合は、その旨（API 判定に失敗したのでブランチ名で推定したこと）をユーザーへの確認・報告に必ず含めること。

### 4-A. protected の場合（未コミットの変更あり）

1. 変更内容から新規ブランチ名を提案する
   - `/push` の引数でブランチ名が指定されていれば**それを使う**（確認は不要）
   - 指定が無ければ、変更内容を要約した ASCII のケバブケース名を提案する（例: `feature/add-push-skill`）
2. `AskUserQuestion` で**必ずユーザーに確認**する
   - 現在のブランチが protected である旨（判定方法も添える）
   - 提案するブランチ名（ユーザーが「Other」で別名を指定できるようにする）
   - ユーザーが拒否した場合は**何もせず中止**する
3. 承認されたら新規ブランチを作成する: `git switch -c <NEW_BRANCH>`
   - 未コミットの変更は作業ツリーに保持されたまま新規ブランチへ引き継がれる
4. `Skill` ツールで `commit` スキルを呼び出してコミットする
5. push する: `git push -u origin <NEW_BRANCH>`

### 4-B. protected でない場合（未コミットの変更あり）

1. `Skill` ツールで `commit` スキルを呼び出してコミットする（ユーザーへの確認は不要）
2. 手順 5 へ進む

### 5. push

- 上流ブランチが設定済み（`git rev-parse --abbrev-ref --symbolic-full-name @{u}` が成功）なら: `git push`
- 未設定なら: `git push -u origin HEAD`
- push が拒否された場合（protected ブランチへの直接 push 禁止、non-fast-forward など）は、**`--force` 系のオプションで再試行しないこと**。拒否理由をそのままユーザーに報告して中止する。

### 6. 結果確認と報告

- `git status -sb` で上流との差分が解消されたことを確認する
- 以下を明示して報告する:
  - push したブランチ名（新規作成した場合はその旨）
  - protected 判定の結果と判定根拠（プロジェクト指示の明記 / API / ブランチ名によるフォールバック）
  - 作成したコミット（`git log --oneline -3`）

## 注意

- `--force` / `--force-with-lease` は**このスキルでは使わない**。必要な場合はユーザーが明示的に指示すること。
- protected でも未コミットの変更が無い場合は、新規ブランチを作らずそのまま push を試みる（可否はリモート側の保護設定に従う）。
