# TODO

- [x] 現状の移行ギャップを整理し、修正方針を確定する
- [x] `install.sh` の Codex `config.toml` 更新処理を安全にする
- [x] Codex 向けドキュメントと運用前提を更新する
- [x] reviewer で再レビューし、指摘があれば修正する
- [x] 結果と残課題をレビュー欄に記録する

## Review

- 2026-04-05: 初回レビューで `config.toml` 上書き、README 未更新、Codex の `.env` 保護差分が指摘されたため修正。
- 2026-04-05: 再レビューで空の `config.toml` への耐性、serializer の型対応、`tasks/` 記録不足が指摘されたため修正。
- 2026-04-05: 最終レビューで README の絶対パス参照と `.codex` ローカルマーカーの扱いが指摘されたため、README 修正と `.gitignore` 追加で解消。
- 2026-04-05: 追加レビューで `tomllib` 依存の Python 3.11 差分が指摘されたため、`tomli` フォールバックと README 注記を追加。
- 2026-04-05: 最終 safety review で unsupported TOML 構造の silent 破壊リスクが指摘されたため、明示エラーで停止する validation を追加。
- 2026-04-05: `Stop` hook が subagent 完了でも通知されることを実測し、transcript の `session_meta.payload.source.subagent` を見て subagent 通知を抑止するガードを追加。
- 2026-04-05: `install.sh` の構文確認、`HOME=/tmp/...` での install 試験、既存 `config.toml` を保持する merge 試験を実施。
