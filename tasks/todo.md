# TODO

- [x] Codex sandboxing を既定値依存ではなく明示設定にする方針で差分を確定する
- [x] `codex/config.toml.base` と `install.sh` の default 値に `sandbox_mode = "workspace-write"` を追加する
- [x] README の Codex Notes を明示 sandbox 設定前提に更新する
- [x] 動作確認と差分確認を行い、Review を記録する
- [x] コミットや push の前に `review-local-changes` 相当のサブエージェントレビューを実施する

## Review

- 2026-04-18: Codex sandboxing は docs 上 `workspace-write` が low-friction default だが、dotfiles としては既定値依存より明示設定の方が再現性が高いため、`sandbox_mode = "workspace-write"` を `codex/config.toml.base` と installer defaults に追加。
- 2026-04-18: README に `sandbox_mode = "workspace-write"` と `approval_policy = "on-request"` を default として明示し、未設定環境に適用する旨を追記。
- 2026-04-18: `bash -n install.sh` と `git diff` で差分を確認。
- 2026-04-18: `review-local-changes` 相当のサブエージェントレビューで README の表現過多と `tasks/todo.md` のレビュー手順欠落が指摘されたため修正。
- 2026-04-18: fresh reviewer の最終再確認で `No findings. LGTM.` を取得。
- 2026-04-18: ローカル `~/.codex/config.toml` と比較し、`features.memories = true` と `tui.status_line` の差分を `codex/config.toml.base` / `install.sh` に反映。README に `~/.codex/memories/` と installer 非管理の前提を追記。
- 2026-04-18: `review-local-changes` 相当のサブエージェントレビューで `context-usage` token の誤りと review 記録の矛盾が指摘されたため、`context-used` へ修正し、レビュー実施済みの記録に更新。
- 2026-04-18: 再レビューで `Installed Paths` と runtime data の責務が混在していたため、`~/.codex/memories/` を installer 管理一覧から外し、Codex-managed runtime data として説明を修正。
- 2026-04-18: fresh reviewer の最終再確認で `No findings. LGTM.` を取得。
- 2026-04-18: `bash -n install.sh`、`git diff`、Codex binary の `strings` 確認で `context-used` / `context-remaining` / `context-remaining-percent` / `weekly-limit` を検証。
- 2026-04-05: 初回レビューで `config.toml` 上書き、README 未更新、Codex の `.env` 保護差分が指摘されたため修正。
- 2026-04-05: 再レビューで空の `config.toml` への耐性、serializer の型対応、`tasks/` 記録不足が指摘されたため修正。
- 2026-04-05: 最終レビューで README の絶対パス参照と `.codex` ローカルマーカーの扱いが指摘されたため、README 修正と `.gitignore` 追加で解消。
- 2026-04-05: 追加レビューで `tomllib` 依存の Python 3.11 差分が指摘されたため、`tomli` フォールバックと README 注記を追加。
- 2026-04-05: 最終 safety review で unsupported TOML 構造の silent 破壊リスクが指摘されたため、明示エラーで停止する validation を追加。
- 2026-04-05: `Stop` hook が subagent 完了でも通知されることを実測し、transcript の `session_meta.payload.source.subagent` を見て subagent 通知を抑止するガードを追加。
- 2026-04-05: `install.sh` の構文確認、`HOME=/tmp/...` での install 試験、既存 `config.toml` を保持する merge 試験を実施。
