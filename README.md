# dotfiles

Personal dotfiles – configurations for Claude Code and other tools.

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

Claude Code を再起動して設定を反映させてください。

## Security

`claude/hooks/common/` には全プラットフォーム共通のセキュリティ hook が含まれます。

| Hook | 対象ツール | 内容 |
| --- | --- | --- |
| `block-dotenv.sh` | Read / Edit / Write / MultiEdit / NotebookEdit | `.env`・`.env.?*`・`.envrc` へのアクセスをブロック |
| `block-rm-rf.sh` | Bash | `rm -rf` / `rm -fr` の実行をブロック |

> **Note:** Claude Code の glob パターン（`deny` ルール）は `.env.*` を正しく展開できないため、hook で代替しています。

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
