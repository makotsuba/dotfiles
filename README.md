# dotfiles

Personal dotfiles – configurations for Claude Code and other tools.

## Prerequisites

### Platform support

| Platform | Status |
| --- | --- |
| WSL (Windows) | ✅ |
| macOS | ✅ |
| Linux (native) | 🚧 Coming soon |

### Sandbox (WSL)

WSL では sandbox の動作に追加の依存関係が必要です。`install.sh` を実行する前にインストールしてください。

```bash
sudo apt install -y bubblewrap socat
npm install -g @anthropic-ai/sandbox-runtime
```

`install.sh` は `@anthropic-ai/sandbox-runtime` を自動検出し、Volta のパッケージパスから `npm root -g` のパスへ symlink を作成します。

> **Note:** Volta を使用していない場合、`npm install -g @anthropic-ai/sandbox-runtime` だけで自動検出されるため symlink 作成はスキップされます。

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
