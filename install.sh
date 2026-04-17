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

merge_codex_config() {
    python3 - <<PYEOF
import json
import os
import shutil
import sys
from datetime import date, datetime, time

try:
    import tomllib
except ModuleNotFoundError:
    try:
        import tomli as tomllib
    except ModuleNotFoundError:
        tomllib = None

config_path = os.path.join(os.path.expanduser("~"), ".codex", "config.toml")

defaults = {
    "sandbox_mode": "workspace-write",
    "approval_policy": "on-request",
    "features": {
        "codex_hooks": True,
        "memories": True,
    },
    "tui": {
        "status_line": [
            "model-with-reasoning",
            "context-used",
            "current-dir",
            "git-branch",
            "five-hour-limit",
            "weekly-limit",
        ],
        "notifications": ["approval-requested"],
        "notification_method": "osc9",
    },
}

def load_existing(path):
    if not os.path.exists(path):
        return {}
    with open(path, "r", encoding="utf-8") as fh:
        raw = fh.read()
    # Empty or comment-only config files should not break reinstall.
    meaningful_lines = [
        line for line in raw.splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    ]
    if not meaningful_lines:
        return {}
    if tomllib is None:
        raise RuntimeError(
            "Codex config merge requires Python 3.11+ or the tomli package"
        )
    try:
        return tomllib.loads(raw)
    except tomllib.TOMLDecodeError:
        raise

def merge_defaults(target, source):
    for key, value in source.items():
        if key not in target:
            target[key] = value
            continue
        if isinstance(value, dict) and isinstance(target.get(key), dict):
            merge_defaults(target[key], value)

def validate_value(path, value):
    if isinstance(value, dict):
        for key, item in value.items():
            validate_value(path + [str(key)], item)
        return
    if isinstance(value, list):
        for index, item in enumerate(value):
            if isinstance(item, (dict, list)):
                dotted = ".".join(path) if path else "<root>"
                raise RuntimeError(
                    f"Unsupported TOML structure at {dotted}[{index}]"
                )
            validate_value(path + [str(index)], item)
        return
    if isinstance(value, (bool, str, int, float, date, datetime, time)):
        return
    raise RuntimeError(
        f"Unsupported TOML value at {'.'.join(path) if path else '<root>'}: {value!r}"
    )

def format_key(key):
    if key.replace("_", "").replace("-", "").isalnum():
        return key
    return json.dumps(key)

def format_value(value):
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, str):
        return json.dumps(value)
    if isinstance(value, list):
        return "[" + ", ".join(format_value(item) for item in value) + "]"
    if isinstance(value, dict):
        items = ", ".join(
            f"{format_key(key)} = {format_value(item)}"
            for key, item in value.items()
        )
        return "{ " + items + " }"
    if isinstance(value, int):
        return str(value)
    if isinstance(value, float):
        return repr(value)
    if isinstance(value, (date, datetime, time)):
        return value.isoformat()
    raise TypeError(f"Unsupported TOML value: {value!r}")

def emit_table(lines, path, table):
    scalars = []
    subtables = []
    for key, value in table.items():
        if isinstance(value, dict):
            subtables.append((key, value))
        else:
            scalars.append((key, value))

    wrote_header = False
    if path and scalars:
        header = ".".join(format_key(part) for part in path)
        lines.append(f"[{header}]")
        wrote_header = True
    for key, value in scalars:
        lines.append(f"{format_key(key)} = {format_value(value)}")
    if wrote_header:
        lines.append("")

    for key, value in subtables:
        emit_table(lines, path + [key], value)

try:
    existing = load_existing(config_path)
    merged = existing.copy()
    merge_defaults(merged, defaults)
    validate_value([], merged)
except RuntimeError as exc:
    print(f"Error: {exc}", file=sys.stderr)
    sys.exit(1)

if os.path.exists(config_path):
    shutil.copy2(config_path, config_path + ".bak")

lines = []

top_level_scalars = []
top_level_tables = []
for key, value in merged.items():
    if isinstance(value, dict):
        top_level_tables.append((key, value))
    else:
        top_level_scalars.append((key, value))

for key, value in top_level_scalars:
    lines.append(f"{format_key(key)} = {format_value(value)}")
if top_level_scalars:
    lines.append("")

for key, value in top_level_tables:
    emit_table(lines, [key], value)

content = "\n".join(lines).rstrip() + "\n"
with open(config_path, "w", encoding="utf-8") as fh:
    fh.write(content)

print("  config.toml updated (preserved existing settings, added missing defaults)")
if os.path.exists(config_path + ".bak"):
    print(f"  backup: {config_path}.bak")
PYEOF
}

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

        # Merge config.toml: preserve existing settings and add missing defaults
        merge_codex_config

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

        merge_codex_config

        echo "Codex Mac setup complete."
        ;;
    *)
        echo "Unsupported OS for Codex: $OS"
        ;;
esac

echo "Done! Codex dotfiles installed to $CODEX_DIR"
