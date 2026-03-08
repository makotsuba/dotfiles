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
# bwrap cannot mount tmpfs on symlinks, so replace symlink with a real directory
if [ -L "$HOME/.aws" ]; then
    echo "  ~/.aws is a symlink; replacing with a real directory so bwrap can mount it..."
    rm "$HOME/.aws"
fi
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
        # Pre-flight: all sandbox dependencies are required for Claude Code sandbox on WSL
        if ! command -v bwrap &>/dev/null || ! command -v socat &>/dev/null; then
            echo "Error: bubblewrap and socat are required." >&2
            echo "  Run: sudo apt install -y bubblewrap socat" >&2
            exit 1
        fi
        NPM_GLOBAL=$(npm root -g 2>/dev/null)
        if [ -z "$NPM_GLOBAL" ]; then
            echo "Error: npm root -g failed. Install Node.js before running this script." >&2
            exit 1
        fi
        SANDBOX_PKG="$NPM_GLOBAL/@anthropic-ai/sandbox-runtime"
        if [ ! -d "$SANDBOX_PKG" ]; then
            echo "Error: @anthropic-ai/sandbox-runtime is not installed." >&2
            echo "  Run: npm install -g @anthropic-ai/sandbox-runtime" >&2
            exit 1
        fi
        echo "  seccomp: @anthropic-ai/sandbox-runtime found at $SANDBOX_PKG"

        shopt -s nullglob
        for hook in "$DOTFILES_DIR/claude/hooks/wsl/"*.sh \
                    "$DOTFILES_DIR/claude/hooks/common/"*.sh; do
            ln -sf "$hook" "$HOOKS_DIR/$(basename "$hook")"
        done
        shopt -u nullglob
        TMP=$(mktemp "$CLAUDE_DIR/settings.json.XXXXXX")
        sed "s|__HOOKS_DIR__|$HOOKS_DIR|g" \
            "$DOTFILES_DIR/claude/settings/wsl.json" > "$TMP"
        mv "$TMP" "$CLAUDE_DIR/settings.json"
        git config --global core.sshCommand ssh.exe

        echo "WSL setup complete."
        ;;
    mac)
        shopt -s nullglob
        for hook in "$DOTFILES_DIR/claude/hooks/mac/"*.sh \
                    "$DOTFILES_DIR/claude/hooks/common/"*.sh; do
            ln -sfh "$hook" "$HOOKS_DIR/$(basename "$hook")"
        done
        shopt -u nullglob
        TMP=$(mktemp "$CLAUDE_DIR/settings.json.XXXXXX")
        sed "s|__HOOKS_DIR__|$HOOKS_DIR|g" \
            "$DOTFILES_DIR/claude/settings/mac.json" > "$TMP"
        mv "$TMP" "$CLAUDE_DIR/settings.json"
        echo "Mac setup complete."
        ;;
    *)
        echo "Unsupported OS: $OS"
        exit 1
        ;;
esac

echo "Done! Claude Code dotfiles installed to $CLAUDE_DIR"
