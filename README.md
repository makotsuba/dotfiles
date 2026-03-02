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
├── install.sh                  # Setup script (auto-detects OS)
└── claude/
    ├── CLAUDE.md               # Global instructions for Claude Code
    ├── keybindings.json        # Key bindings
    ├── agents/                 # Custom agent definitions
    ├── skills/                 # Custom skills
    ├── hooks/
    │   └── wsl/                # WSL-specific hooks (Windows notifications)
    └── settings/
        └── wsl.json            # WSL settings template
```

## Platform support

| Platform | Status |
|---|---|
| WSL (Windows) | ✅ |
| macOS | 🚧 Coming soon |
