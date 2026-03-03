# dotfiles

Personal dotfiles – configurations for Claude Code and other tools.

## Setup

> **WSL の場合:** sandbox を完全に有効化するには、先に [Sandbox (WSL)](#sandbox-wsl) の依存関係をインストールしてください。

```bash
git clone git@github.com:makotsuba/dotfiles.git ~/dotfiles
cd ~/dotfiles
bash install.sh
```

## Structure

```text
dotfiles/
├── install.sh                      # Setup script (auto-detects OS)
└── claude/
    ├── CLAUDE.md                   # Global instructions for Claude Code
    ├── keybindings.json            # Key bindings
    ├── agents/                     # Custom agent definitions
    ├── skills/                     # Custom skills
    ├── hooks/
    │   ├── common/                 # Shared across all platforms
    │   ├── wsl/                    # WSL-specific (Windows notifications)
    │   └── mac/                    # macOS-specific (osascript notifications)
    └── settings/
        ├── wsl.json                # WSL settings template
        └── mac.json                # macOS settings template
```

## Platform support

| Platform | Status |
| --- | --- |
| WSL (Windows) | ✅ |
| macOS | ✅ |
| Linux (native) | 🚧 Coming soon |

## Sandbox (WSL)

WSL では sandbox の完全な動作に追加の依存関係が必要です。`install.sh` を実行する前にインストールしてください。

```bash
sudo apt install -y bubblewrap socat
npm install -g @anthropic-ai/sandbox-runtime
```

`install.sh` は `@anthropic-ai/sandbox-runtime` を自動検出し、seccomp の設定を書き込みます。インストール後に `install.sh` を再実行すれば設定されます。
