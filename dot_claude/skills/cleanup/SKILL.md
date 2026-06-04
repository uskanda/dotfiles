---
name: cleanup
description: 4時間以上前に開始された自分以外のClaude Codeプロセスをkillしてメモリを解放する
disable-model-invocation: true
allowed-tools: Bash
---

# 古いClaude Codeプロセスのクリーンアップ

以下の手順を実行してください。

## 手順

1. まず `free -h` でメモリ状況を確認する
2. 自分自身のPID (`$PPID`) を確認する
3. 2時間以上前に起動された `anthropic.claude-code` を含むプロセスを一覧表示する（自分自身のPIDは除外）
4. 該当プロセスがあれば `kill` で終了させる。SIGTERM後2秒待っても残っているプロセスには `kill -9` を送る
5. 最後に再度 `free -h` でメモリ状況を表示し、解放されたメモリ量を報告する

## 注意事項

- 自分自身のプロセス ($PPID) は絶対にkillしないこと
- プロセスの経過時間は `ps -eo pid,lstart,args` の lstart から計算すること
- 結果はkillしたプロセス数・解放前後のメモリ使用量を簡潔に報告すること
