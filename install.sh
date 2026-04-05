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
mkdir -p "$CLAUDE_DIR/hooks" "$CLAUDE_DIR/agents" "$CLAUDE_DIR/skills/fix-issue" "$CLAUDE_DIR/skills/review-pr" "$CLAUDE_DIR/skills/skill-creator/references"

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
ln -sf "$DOTFILES_DIR/claude/skills/fix-issue/SKILL.md"                        "$CLAUDE_DIR/skills/fix-issue/SKILL.md"
ln -sf "$DOTFILES_DIR/claude/skills/review-pr/SKILL.md"                        "$CLAUDE_DIR/skills/review-pr/SKILL.md"
ln -sf "$DOTFILES_DIR/claude/skills/skill-creator/SKILL.md"                    "$CLAUDE_DIR/skills/skill-creator/SKILL.md"
ln -sf "$DOTFILES_DIR/claude/skills/skill-creator/references/guide.md"         "$CLAUDE_DIR/skills/skill-creator/references/guide.md"

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
            chmod +x "$hook"
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
            chmod +x "$hook"
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

# ---------------------------------------------------------------------------
# Codex setup
# ---------------------------------------------------------------------------
CODEX_DIR="$HOME/.codex"
CODEX_HOOKS_DIR="$CODEX_DIR/hooks"
AGENTS_SKILLS_DIR="$HOME/.agents/skills"
mkdir -p "$CODEX_HOOKS_DIR" "$CODEX_DIR/agents" "$AGENTS_SKILLS_DIR"

# Symlink AGENTS.md
ln -sf "$DOTFILES_DIR/codex/AGENTS.md" "$CODEX_DIR/AGENTS.md"

# Symlink subagents (TOML files)
for agent in "$DOTFILES_DIR/codex/agents/"*.toml; do
    ln -sf "$agent" "$CODEX_DIR/agents/$(basename "$agent")"
done

# Symlink skills to ~/.agents/skills/ (entire directory to include references/, scripts/, assets/)
python3 - <<PYEOF
import os, shutil

dotfiles_dir = "$DOTFILES_DIR"
agents_skills_dir = os.path.join(os.path.expanduser("~"), ".agents", "skills")
os.makedirs(agents_skills_dir, exist_ok=True)

skills_source = os.path.join(dotfiles_dir, "codex", "skills")
for skill_name in sorted(os.listdir(skills_source)):
    skill_dir = os.path.join(skills_source, skill_name)
    if not os.path.isdir(skill_dir):
        continue
    target = os.path.join(agents_skills_dir, skill_name)
    if os.path.islink(target):
        os.unlink(target)
    elif os.path.isdir(target):
        shutil.rmtree(target)
    os.symlink(skill_dir, target)
    print(f"  skill: {skill_name}")
PYEOF

case "$OS" in
    wsl)
        # Symlink hook scripts:
        #   - codex/hooks/wsl/: WSL-specific (notify-stop.sh)
        #   - codex/hooks/common/: Codex-specific common hooks (block-dotenv-bash.sh)
        #   - claude/hooks/common/block-rm-rf.sh: shared guard (same JSON format)
        # NOTE: block-dotenv-bash.sh covers shell-based .env access (cat, vim, echo >, etc.)
        #       Native file tool interception is unsupported (Codex PreToolUse: Bash only).
        shopt -s nullglob
        for hook in "$DOTFILES_DIR/codex/hooks/wsl/"*.sh \
                    "$DOTFILES_DIR/codex/hooks/common/"*.sh \
                    "$DOTFILES_DIR/claude/hooks/common/block-rm-rf.sh"; do
            ln -sf "$hook" "$CODEX_HOOKS_DIR/$(basename "$hook")"
            chmod +x "$hook"
        done
        shopt -u nullglob

        # Generate hooks.json
        TMP=$(mktemp)
        sed "s|__HOOKS_DIR__|$CODEX_HOOKS_DIR|g" \
            "$DOTFILES_DIR/codex/hooks.json.template" > "$TMP"
        mv "$TMP" "$CODEX_DIR/hooks.json"

        # Merge config.toml: write base settings, preserve existing project trust lines
        python3 - <<PYEOF
import re, os

config_path = os.path.join(os.path.expanduser("~"), ".codex", "config.toml")
base_path   = os.path.join("$DOTFILES_DIR", "codex", "config.toml.base")

existing = open(config_path).read() if os.path.exists(config_path) else ""

# Extract [projects.*] blocks (trust_level lines)
project_blocks = re.findall(
    r'(\[projects\.[^\]]+\]\ntrust_level\s*=\s*"[^"]+"\n)',
    existing
)

base = open(base_path).read()
new_config = base.rstrip("\n") + "\n"
if project_blocks:
    new_config += "\n" + "".join(project_blocks)

open(config_path, "w").write(new_config)
print(f"  config.toml updated (preserved {len(project_blocks)} project trust entries)")
PYEOF

        echo "Codex WSL setup complete."
        ;;
    mac)
        shopt -s nullglob
        for hook in "$DOTFILES_DIR/codex/hooks/mac/"*.sh \
                    "$DOTFILES_DIR/codex/hooks/common/"*.sh \
                    "$DOTFILES_DIR/claude/hooks/common/block-rm-rf.sh"; do
            ln -sfh "$hook" "$CODEX_HOOKS_DIR/$(basename "$hook")"
            chmod +x "$hook"
        done
        shopt -u nullglob

        TMP=$(mktemp)
        sed "s|__HOOKS_DIR__|$CODEX_HOOKS_DIR|g" \
            "$DOTFILES_DIR/codex/hooks.json.template" > "$TMP"
        mv "$TMP" "$CODEX_DIR/hooks.json"

        python3 - <<PYEOF
import re, os

config_path = os.path.join(os.path.expanduser("~"), ".codex", "config.toml")
base_path   = os.path.join("$DOTFILES_DIR", "codex", "config.toml.base")

existing = open(config_path).read() if os.path.exists(config_path) else ""
project_blocks = re.findall(
    r'(\[projects\.[^\]]+\]\ntrust_level\s*=\s*"[^"]+"\n)',
    existing
)

base = open(base_path).read()
new_config = base.rstrip("\n") + "\n"
if project_blocks:
    new_config += "\n" + "".join(project_blocks)

open(config_path, "w").write(new_config)
print(f"  config.toml updated (preserved {len(project_blocks)} project trust entries)")
PYEOF

        echo "Codex Mac setup complete."
        ;;
    *)
        echo "Unsupported OS for Codex: $OS"
        ;;
esac

echo "Done! Codex dotfiles installed to $CODEX_DIR"
