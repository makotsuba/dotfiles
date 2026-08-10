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

#### fish / Starship の移行前監査

WSL の既存 shell 設定を管理対象にする前に、次を実行して出力を確認します。設定値、symlink の参照先、`.env` は表示しません。

```bash
sh ~/dotfiles/scripts/audit-wsl-shell.sh
```

alias / abbr の名前と Starship の環境マネージャー関連 module 名だけも確認する場合は、`--details` を付けます。複雑な宣言は値を出さずに省略し、Starship は `direnv`・`conda`・`nix_shell`・`mise`・`pixi` と、言語 module 内の pyenv / rbenv / nvm / asdf / mise 設定だけを対象にします。

```bash
sh ~/dotfiles/scripts/audit-wsl-shell.sh --details
```

#### fish / Starship の管理

WSL の fish と主 Starship profile は、監査後に installer で管理します。事前に fish、Starship、Windows 側の 1Password / OpenSSH command が利用可能であることを確認してください。`op.exe`、`ssh.exe`、`ssh-add.exe` が見つからない場合、対応する abbreviation は作られず Linux 側の command を使います。

```bash
command -v fish starship op.exe ssh.exe ssh-add.exe
cd ~/dotfiles
bash install.sh
```

installer は既存の通常ファイル・別先の symlink・dangling symlink を `~/.dotfiles-backups/fish-starship-*/` へ退避してから、次の3ファイルを管理します。実ディレクトリが置かれている場合は安全のため停止し、変更しません。

- `~/.config/fish/config.fish`
- `~/.config/fish/wsl-abbreviations.fish`（WSL の対話 session 専用）
- `~/.config/starship.toml`

復元する場合は、installer が表示した backup directory を使います。対象の symlink が dotfiles を指すことを確認してから、その**対象ファイルだけ**を別名に退避し、対応する backup 内のファイルを元のパスへ戻してください。backup directory 全体を削除する必要はありません。Windows Terminal では、Nerd Font（例: `PlemolJP Console NF`）をホスト側の profile に設定してください。この installer は Windows Terminal / PowerShell の設定、既定 shell、パッケージを変更しません。

### macOS（fish・Starship・cmux）

core の shell 環境は、Homebrew を導入した後に次の順でセットアップします。`brew bundle check` は依存が不足していると non-zero で終了しますが、導入前の確認として正常な挙動です。

```bash
brew bundle check --no-upgrade --file ~/dotfiles/Brewfile
brew bundle install --no-upgrade --file ~/dotfiles/Brewfile
```

`--no-upgrade` は既に入っているパッケージを更新せず、不足分だけを導入します。この Bundle には Codex の設定 merge に必要な Homebrew Python も含まれます。

cmux は macOS 14 以降でのみ追加します。新規に導入する場合は、次の Bundle を実行してください。

```bash
brew bundle check --no-upgrade --file ~/dotfiles/Brewfile.cmux
brew bundle install --no-upgrade --file ~/dotfiles/Brewfile.cmux
```

すでに `/Applications/cmux.app` を Homebrew 以外で導入している場合は、上の Bundle を実行せず、最初に次を一度だけ実行します。同じ App bundle の場合だけ Homebrew 管理下へ登録されます。失敗した場合は `--force` や手動削除をせず、既存 app をそのまま使って原因を確認してください。成功後は `brew bundle check --no-upgrade --file ~/dotfiles/Brewfile.cmux` で確認できます。

```bash
brew install --cask --adopt cmux
```

cmux cask は `auto_updates` です。通常の更新は cmux 自身に任せ、Homebrew から明示的に更新確認する場合だけ次を実行します。

```bash
brew upgrade --cask --greedy-auto-updates cmux
```

`bash install.sh` の後に fish を login shell にする場合は、`/opt/homebrew/bin/fish` が `/etc/shells` に登録されていることを確認してから次を実行します。

```bash
chsh -s /opt/homebrew/bin/fish
```

zsh へ戻す場合は `chsh -s /bin/zsh` を実行します。Terminal.app は Settings > General > **Shells open with** で **Default login shell** を選び、Profiles > Text の Font を `PlemolJP Console NF` の 15 pt にしてください。

VS Code は user `settings.json` 全体を上書きせず、次の terminal 関連設定だけを既存設定へ追加します。

```jsonc
{
  "terminal.integrated.fontFamily": "'PlemolJP Console NF', monospace",
  "terminal.integrated.fontSize": 15,
  "terminal.integrated.fontWeight": "normal",
  "terminal.integrated.profiles.osx": {
    "fish": { "path": "/opt/homebrew/bin/fish" }
  },
  "terminal.integrated.defaultProfile.osx": "fish",
  "terminal.integrated.automationProfile.osx": { "path": "/bin/sh" }
}
```

cmux は `~/.config/ghostty/config` を読みます。設定変更後は cmux を再起動するか、cmux 内で `⌘⇧,` を実行してください。

## Setup

すべての環境で、まずリポジトリを取得します。

```bash
git clone git@github.com:makotsuba/dotfiles.git ~/dotfiles
cd ~/dotfiles
```

macOS では、上記の cmux 手順を済ませた後、core Bundle を導入してから installer を実行します。これにより Codex 設定 merge に必要な Homebrew Python が先に利用可能になります。

```bash
brew bundle install --no-upgrade --file ~/dotfiles/Brewfile
bash install.sh
```

WSL では、上記の fish / Starship 前提を満たした後に `cd ~/dotfiles` の後に `bash install.sh` を実行します。

## Update

macOS では、installer の前に core Bundle を充足させます。

```bash
git pull
brew bundle install --no-upgrade --file ~/dotfiles/Brewfile
bash install.sh
```

WSL では、fish / Starship と Windows 側 command の確認後に次を実行します。

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

### Shell prompt

#### macOS

- `~/.config/fish/config.fish`
- `~/.config/starship.toml`
- `~/.config/starship-terminal.toml`
- `~/.config/ghostty/config`

#### WSL

- `~/.config/fish/config.fish`
- `~/.config/fish/wsl-abbreviations.fish`
- `~/.config/starship.toml`

## Security

Claude Code と Codex の両方で、共通の安全ガードを有効にします。

| Tool | Hook | 対象 | 内容 |
| --- | --- | --- |
| Claude Code | `block-dotenv.sh` | Read / Edit / Write / MultiEdit / NotebookEdit | `.env`・`.env.?*`・`.envrc` へのアクセスをブロック |
| Claude Code | `block-rm-rf.sh` | Bash | `rm -rf` / `rm -fr` の実行をブロック |
| Codex | `block-dotenv-bash.sh` | Bash | shell 経由の `.env`・`.env.?*`・`.envrc` アクセスをブロック |
| Codex | `block-rm-rf.sh` | Bash | `rm -rf` / `rm -fr` の実行をブロック |

> **Note:** Codex の `PreToolUse` hook は現在 Bash に対してのみ使用しています。そのため `.env` 保護は Claude Code より狭く、native file tool 相当の経路まではフックできません。運用上は `codex/AGENTS.md` の禁止ルールと併用してください。

fish の `fish_history`・`fish_variables`・補完キャッシュ、`.env*`、direnv、AWS／SSH／1Password の認証情報、Codex の `auth.json`・sessions・logs・cache・memories はこのリポジトリの管理対象外です。VS Code の user `settings.json` 全体と Terminal.app の profile も端末固有のため自動反映しません。

## Codex Notes

- `researcher` と `reviewer` subagent は `codex/agents/researcher.toml` と `codex/agents/reviewer.toml` で定義しています。
- skills は `codex/skills/` から `~/.agents/skills/` へ symlink されます。
- `sandbox_mode = "workspace-write"` と `approval_policy = "on-request"` を default に明示し、未設定環境では Codex の low-friction sandbox を既定値依存ではなく設定から適用します。
- `~/.codex/config.toml` は既存設定を保持したまま、足りないデフォルト値だけを追加します。default では `features.memories = true` を有効化し、更新前の内容は `~/.codex/config.toml.bak` に退避します。
- `memories` の保存先は `~/.codex/memories/` です。これは installer の管理対象ではなく、Codex 本体が生成・更新する runtime data です。
- 既存の `~/.codex/config.toml` を merge するには `python3` の `tomllib` が必要です。Python 3.11 未満を使う場合は `tomli` を追加してください。
- 既存の `~/.codex/config.toml` に array of tables など未対応の構造がある場合、silent に書き換えず installer は明示エラーで停止します。
- WSL / macOS ともに task 完了時の通知 hook を設定します。Claude Code にあった idle 通知は Codex には移植していません。

## Structure

```text
dotfiles/
├── Brewfile                        # Core macOS shell dependencies
├── Brewfile.cmux                   # Optional cmux cask (macOS 14+)
├── install.sh                      # Setup script (auto-detects OS)
├── fish/
│   ├── config.fish                 # Interactive fish setup
│   └── wsl-abbreviations.fish       # WSL interactive abbreviations
├── starship/
│   ├── starship.toml               # cmux / VS Code prompt
│   └── starship-terminal.toml      # Terminal.app prompt
├── ghostty/
│   └── config                      # cmux terminal rendering and shell
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
