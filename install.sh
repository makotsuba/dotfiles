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
        TMP=$(mktemp "$CLAUDE_DIR/settings.json.XXXXXX")
        sed "s|__HOOKS_DIR__|$HOOKS_DIR|g" \
            "$DOTFILES_DIR/claude/settings/wsl.json" > "$TMP"
        mv "$TMP" "$CLAUDE_DIR/settings.json"
        git config --global core.sshCommand ssh.exe

        # Configure sandbox seccomp filter (required to block unix domain sockets)
        SEARCH_PATHS=(
            "$HOME/.volta/tools/image/packages/@anthropic-ai/sandbox-runtime"
            /usr/lib/node_modules/@anthropic-ai/sandbox-runtime
            /usr/local/lib/node_modules/@anthropic-ai/sandbox-runtime
        )
        NPM_GLOBAL=$(npm root -g 2>/dev/null)
        [ -n "$NPM_GLOBAL" ] && SEARCH_PATHS+=("$NPM_GLOBAL/@anthropic-ai/sandbox-runtime")

        SECCOMP_BPF=$(find "${SEARCH_PATHS[@]}" -name "unix-block.bpf" -print -quit 2>/dev/null)
        if [ -n "$SECCOMP_BPF" ] && [ -f "$(dirname "$SECCOMP_BPF")/apply-seccomp" ]; then
            SECCOMP_DIR=$(dirname "$SECCOMP_BPF")
            if ! command -v python3 &>/dev/null; then
                echo "  Warning: python3 not found. Skipping seccomp configuration."
            else
                env CLAUDE_DIR="$CLAUDE_DIR" SECCOMP_DIR="$SECCOMP_DIR" python3 -c "
import json, os, tempfile
claude_dir  = os.environ['CLAUDE_DIR']
seccomp_dir = os.environ['SECCOMP_DIR']
settings    = f'{claude_dir}/settings.json'
with open(settings) as f:
    cfg = json.load(f)
cfg.setdefault('sandbox', {}).setdefault('seccomp', {})
cfg['sandbox']['seccomp']['bpfPath']   = f'{seccomp_dir}/unix-block.bpf'
cfg['sandbox']['seccomp']['applyPath'] = f'{seccomp_dir}/apply-seccomp'
fd, tmp = tempfile.mkstemp(dir=os.path.dirname(settings))
try:
    with os.fdopen(fd, 'w') as f:
        json.dump(cfg, f, indent=2, ensure_ascii=False)
    os.replace(tmp, settings)
except:
    os.unlink(tmp)
    raise
print('  seccomp configured:', seccomp_dir)
"
            fi
        else
            echo "  Warning: @anthropic-ai/sandbox-runtime not found. Run: npm install -g @anthropic-ai/sandbox-runtime"
        fi

        echo "WSL setup complete."
        ;;
    mac)
        for hook in "$DOTFILES_DIR/claude/hooks/mac/"*.sh \
                    "$DOTFILES_DIR/claude/hooks/common/"*.sh; do
            ln -sf "$hook" "$HOOKS_DIR/$(basename "$hook")"
        done
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
