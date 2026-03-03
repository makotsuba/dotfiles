#!/bin/bash
set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
HOOKS_DIR="$CLAUDE_DIR/hooks"

# OS detection
detect_os() {
    if grep -qi microsoft /proc/version 2>/dev/null; then
        echo "wsl"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "mac"
    else
        echo "linux"
    fi
}

OS=$(detect_os)
echo "Detected OS: $OS"

# Create ~/.claude directories
mkdir -p "$CLAUDE_DIR/hooks" "$CLAUDE_DIR/agents" "$CLAUDE_DIR/skills/fix-issue" "$CLAUDE_DIR/skills/review-pr"

# Create directories required by sandbox (must exist to be mounted/blocked)
mkdir -p "$HOME/.aws"

# Symlink shared files
ln -sf "$DOTFILES_DIR/claude/CLAUDE.md"                        "$CLAUDE_DIR/CLAUDE.md"
ln -sf "$DOTFILES_DIR/claude/keybindings.json"                 "$CLAUDE_DIR/keybindings.json"
ln -sf "$DOTFILES_DIR/claude/agents/researcher.md"             "$CLAUDE_DIR/agents/researcher.md"
ln -sf "$DOTFILES_DIR/claude/agents/reviewer.md"               "$CLAUDE_DIR/agents/reviewer.md"
ln -sf "$DOTFILES_DIR/claude/skills/fix-issue/SKILL.md"        "$CLAUDE_DIR/skills/fix-issue/SKILL.md"
ln -sf "$DOTFILES_DIR/claude/skills/review-pr/SKILL.md"        "$CLAUDE_DIR/skills/review-pr/SKILL.md"

# Platform-specific setup
case "$OS" in
    wsl)
        for hook in "$DOTFILES_DIR/claude/hooks/wsl/"*.sh \
                    "$DOTFILES_DIR/claude/hooks/common/"*.sh; do
            ln -sf "$hook" "$HOOKS_DIR/$(basename "$hook")"
        done
        sed "s|__HOOKS_DIR__|$HOOKS_DIR|g" \
            "$DOTFILES_DIR/claude/settings/wsl.json" > "$CLAUDE_DIR/settings.json"
        git config --global core.sshCommand ssh.exe
        echo "WSL setup complete."
        ;;
    mac)
        for hook in "$DOTFILES_DIR/claude/hooks/mac/"*.sh \
                    "$DOTFILES_DIR/claude/hooks/common/"*.sh; do
            ln -sf "$hook" "$HOOKS_DIR/$(basename "$hook")"
        done
        sed "s|__HOOKS_DIR__|$HOOKS_DIR|g" \
            "$DOTFILES_DIR/claude/settings/mac.json" > "$CLAUDE_DIR/settings.json"
        echo "Mac setup complete."
        ;;
    *)
        echo "Unsupported OS: $OS"
        exit 1
        ;;
esac

echo "Done! Claude Code dotfiles installed to $CLAUDE_DIR"
