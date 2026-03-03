# dotfiles

Personal dotfiles – configurations for Claude Code and other tools.

## Setup

```bash
git clone git@github.com:makotsuba/dotfiles.git ~/dotfiles
cd ~/dotfiles
bash install.sh
```

## Structure

```
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
|---|---|
| WSL (Windows) | ✅ |
| macOS | ✅ |

## Sandbox (WSL)

WSL では sandbox の動作に追加の依存関係が必要です。`install.sh` 実行後、Claude Code 内で `/sandbox` を開き Dependencies タブの指示に従ってください。
