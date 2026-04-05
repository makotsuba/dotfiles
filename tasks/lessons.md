# Lessons

- `config.toml` のようなユーザー設定ファイルを installer で更新する場合は、再生成ではなく merge を基本にし、空ファイルと comment-only ファイルも正常系として扱う。
- reviewer 指摘を閉じるときは、コード修正だけでなく `tasks/todo.md` の review 記録と `tasks/lessons.md` の再発防止策まで同じターンで更新する。
- shell の heredoc に埋め込む Python 文字列では、バッククォートが shell 展開されうるので使わない。必要なら通常の引用符に置き換える。
- serializer が完全な round-trip を保証できないなら、未対応構造を best effort で流さず、検出して明示エラーにする。
- hook の発火主体を見分けたいときは、環境変数や親プロセスだけで決め打ちせず、`stdin` の event payload と transcript の `session_meta` を確認する。
