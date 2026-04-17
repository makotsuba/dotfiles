# dotfiles

Personal dotfiles for Claude Code, Codex, and related tooling.

## Prerequisites

### Platform support

| Platform | Status |
| --- | --- |
| WSL (Windows) | ✅ |
| macOS | ✅ |
| Linux (native) | 🚧 Coming soon |

### WSL (Windows)

#### Sandbox

以下は必須の依存関係です。`install.sh` を実行する前にインストールしてください。

> **Note:** 未インストールの場合、スクリプトはエラーで終了します。

```bash
sudo apt install -y bubblewrap socat
npm install -g @anthropic-ai/sandbox-runtime
```

#### Notifications

Windows のトースト通知を受け取るには PowerShell 7 と BurntToast が必要です。

PowerShell 7 のインストール：

```powershell
winget install --id Microsoft.PowerShell --source winget
```

BurntToast のインストール：

```powershell
Install-Module -Name BurntToast -Force
```

## Setup

```bash
git clone git@github.com:makotsuba/dotfiles.git ~/dotfiles
cd ~/dotfiles
bash install.sh
```

## Update

```bash
git pull && bash install.sh
```

`install.sh` は Claude Code と Codex の両方をセットアップします。反映のため、利用中のクライアントを再起動してください。

## Installed Paths

### Claude Code

- `~/.claude/CLAUDE.md`
- `~/.claude/agents/`
- `~/.claude/skills/`
- `~/.claude/hooks/`
- `~/.claude/settings.json`

### Codex

- `~/.codex/AGENTS.md`
- `~/.codex/agents/`
- `~/.codex/hooks/`
- `~/.codex/hooks.json`
- `~/.codex/config.toml`
- `~/.agents/skills/`

## Security

Claude Code と Codex の両方で、共通の安全ガードを有効にします。

| Tool | Hook | 対象 | 内容 |
| --- | --- | --- |
| Claude Code | `block-dotenv.sh` | Read / Edit / Write / MultiEdit / NotebookEdit | `.env`・`.env.?*`・`.envrc` へのアクセスをブロック |
| Claude Code | `block-rm-rf.sh` | Bash | `rm -rf` / `rm -fr` の実行をブロック |
| Codex | `block-dotenv-bash.sh` | Bash | shell 経由の `.env`・`.env.?*`・`.envrc` アクセスをブロック |
| Codex | `block-rm-rf.sh` | Bash | `rm -rf` / `rm -fr` の実行をブロック |

> **Note:** Codex の `PreToolUse` hook は現在 Bash に対してのみ使用しています。そのため `.env` 保護は Claude Code より狭く、native file tool 相当の経路まではフックできません。運用上は `codex/AGENTS.md` の禁止ルールと併用してください。

## Codex Notes

- `researcher` と `reviewer` subagent は `codex/agents/researcher.toml` と `codex/agents/reviewer.toml` で定義しています。
- skills は `codex/skills/` から `~/.agents/skills/` へ symlink されます。
- `~/.codex/config.toml` は既存設定を保持したまま、足りないデフォルト値だけを追加します。default では `features.memories = true` を有効化し、更新前の内容は `~/.codex/config.toml.bak` に退避します。
- `memories` の保存先は `~/.codex/memories/` です。これは installer の管理対象ではなく、Codex 本体が生成・更新する runtime data です。
- 既存の `~/.codex/config.toml` を merge するには `python3` の `tomllib` が必要です。Python 3.11 未満を使う場合は `tomli` を追加してください。
- 既存の `~/.codex/config.toml` に array of tables など未対応の構造がある場合、silent に書き換えず installer は明示エラーで停止します。
- WSL / macOS ともに task 完了時の通知 hook を設定します。Claude Code にあった idle 通知は Codex には移植していません。

## Structure

```text
dotfiles/
├── install.sh                      # Setup script (auto-detects OS)
├── claude/
│   ├── CLAUDE.md                   # Global instructions for Claude Code
│   ├── keybindings.json            # Key bindings
│   ├── agents/                     # Custom agent definitions
│   ├── skills/                     # Custom skills
│   ├── hooks/
│   │   ├── common/                 # Shared across all platforms
│   │   ├── wsl/                    # WSL-specific (Windows notifications)
│   │   └── mac/                    # macOS-specific (osascript notifications)
│   └── settings/
│       ├── wsl.json                # WSL settings template
│       └── mac.json                # macOS settings template
├── codex/
│   ├── AGENTS.md                   # Global instructions for Codex
│   ├── agents/                     # Codex subagent definitions
│   ├── hooks/                      # Codex hook scripts
│   ├── skills/                     # Codex skills
│   ├── config.toml.base            # Default Codex config values
│   └── hooks.json.template         # Hook template expanded by install.sh
└── tasks/
    ├── todo.md                     # Working plan / review notes
    └── lessons.md                  # Reusable lessons after corrections
```
