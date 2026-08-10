#!/bin/bash
set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
HOOKS_DIR="$CLAUDE_DIR/hooks"
CODEX_DIR="$HOME/.codex"
CODEX_HOOKS_DIR="$CODEX_DIR/hooks"
AGENTS_SKILLS_DIR="$HOME/.agents/skills"
DOTFILES_BACKUP_DIR=""
PYTHON3_BIN=""
COMPONENTS_SPEC="all"
INSTALL_CLAUDE=false
INSTALL_CODEX=false
INSTALL_SHELL=false
SHELL_TRANSACTION_ACTIVE=false
SHELL_LINK_ATTEMPTS=()
SHELL_BACKUP_TARGETS=()
SHELL_BACKUP_SOURCES=()

usage() {
    cat <<'EOF'
Usage: bash install.sh [--components all|claude,codex,shell]

Components:
  claude  Install Claude Code settings and WSL sandbox integration.
  codex   Install Codex settings, skills, and hooks.
  shell   Install fish and Starship settings for the detected OS.

With no arguments, all components are installed for backward compatibility.
EOF
}

fail() {
    echo "Error: $*" >&2
    return 1
}

parse_components() {
    case "$#" in
        0)
            ;;
        1)
            if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
                usage
                exit 0
            fi
            fail "unknown option: $1"
            return 1
            ;;
        2)
            if [ "$1" != "--components" ]; then
                fail "unknown option: $1"
                return 1
            fi
            COMPONENTS_SPEC="$2"
            ;;
        *)
            fail "expected --components followed by a comma-separated list"
            return 1
            ;;
    esac

    if [ "$COMPONENTS_SPEC" = "all" ]; then
        INSTALL_CLAUDE=true
        INSTALL_CODEX=true
        INSTALL_SHELL=true
        return 0
    fi

    if [ -z "$COMPONENTS_SPEC" ]; then
        fail "component list must not be empty"
        return 1
    fi

    case "$COMPONENTS_SPEC" in
        ,*|*,|*,,*)
            fail "component list must not contain empty values"
            return 1
            ;;
        *[!a-z,]*)
            fail "component list must contain lowercase names separated by commas"
            return 1
            ;;
    esac

    local component
    local -a components
    IFS=',' read -r -a components <<< "$COMPONENTS_SPEC"

    for component in "${components[@]}"; do
        if [ -z "$component" ]; then
            fail "component list must not contain empty values"
            return 1
        fi

        case "$component" in
            claude)
                if [ "$INSTALL_CLAUDE" = true ]; then
                    fail "duplicate component: claude"
                    return 1
                fi
                INSTALL_CLAUDE=true
                ;;
            codex)
                if [ "$INSTALL_CODEX" = true ]; then
                    fail "duplicate component: codex"
                    return 1
                fi
                INSTALL_CODEX=true
                ;;
            shell)
                if [ "$INSTALL_SHELL" = true ]; then
                    fail "duplicate component: shell"
                    return 1
                fi
                INSTALL_SHELL=true
                ;;
            *)
                fail "unknown component: $component"
                return 1
                ;;
        esac
    done
}

require_command() {
    local command_name="$1"

    if ! command -v "$command_name" &>/dev/null; then
        fail "required command is unavailable: $command_name"
        return 1
    fi
}

preflight_global_git_config() {
    local config_path
    local config_parent

    if [ -n "${GIT_CONFIG_GLOBAL:-}" ]; then
        config_path="$GIT_CONFIG_GLOBAL"
    elif [ -e "$HOME/.gitconfig" ] || [ -L "$HOME/.gitconfig" ]; then
        config_path="$HOME/.gitconfig"
    elif [ -e "${XDG_CONFIG_HOME:-$HOME/.config}/git/config" ] || \
         [ -L "${XDG_CONFIG_HOME:-$HOME/.config}/git/config" ]; then
        config_path="${XDG_CONFIG_HOME:-$HOME/.config}/git/config"
    else
        config_path="$HOME/.gitconfig"
    fi

    config_parent=$(dirname "$config_path")
    if [ ! -d "$config_parent" ] || [ -L "$config_parent" ] || [ ! -w "$config_parent" ]; then
        fail "global Git config parent is not a writable real directory: $config_parent"
        return 1
    fi

    if [ -e "$config_path" ] || [ -L "$config_path" ]; then
        if [ -L "$config_path" ] || [ ! -f "$config_path" ]; then
            fail "global Git config is not a regular file: $config_path"
            return 1
        fi
        if [ ! -w "$config_path" ]; then
            fail "global Git config is not writable: $config_path"
            return 1
        fi
    fi

    if ! git config --global --list >/dev/null 2>&1; then
        fail "global Git config is unreadable; repair it before selecting Claude"
        return 1
    fi
}

require_source_file() {
    local source="$1"

    if [ ! -e "$source" ]; then
        fail "managed source is missing: $source"
        return 1
    fi
}

ensure_dotfiles_backup_dir() {
    if [ -n "$DOTFILES_BACKUP_DIR" ]; then
        return
    fi

    local backup_root="$HOME/.dotfiles-backups"
    if ! mkdir -p "$backup_root"; then
        return 1
    fi
    if ! DOTFILES_BACKUP_DIR=$(mktemp -d "$backup_root/fish-starship-$(date +%Y%m%d-%H%M%S).XXXXXX"); then
        return 1
    fi
    echo "  backup directory: $DOTFILES_BACKUP_DIR"
}

validate_managed_target() {
    local target="$1"

    if [ -d "$target" ]; then
        echo "Error: expected a file but found a directory: $target" >&2
        echo "  Leave it unchanged and move it manually before rerunning the installer." >&2
        return 1
    fi
}

validate_managed_directory() {
    local directory="$1"

    if { [ -e "$directory" ] || [ -L "$directory" ]; } && \
       { [ ! -d "$directory" ] || [ -L "$directory" ]; }; then
        echo "Error: expected a real directory: $directory" >&2
        echo "  Leave it unchanged and move it manually before rerunning the installer." >&2
        return 1
    fi
}

validate_regular_file_target() {
    local target="$1"

    if { [ -e "$target" ] || [ -L "$target" ]; } && \
       { [ ! -f "$target" ] || [ -L "$target" ]; }; then
        echo "Error: expected an absent or regular file: $target" >&2
        echo "  Leave it unchanged and move it manually before rerunning the installer." >&2
        return 1
    fi
}

resolve_python3() {
    if [ -n "$PYTHON3_BIN" ]; then
        return
    fi

    if command -v brew &>/dev/null; then
        local homebrew_python_prefix
        local homebrew_python
        if homebrew_python_prefix=$(brew --prefix python 2>/dev/null); then
            for homebrew_python in "$homebrew_python_prefix"/bin/python3.*; do
                if [ -x "$homebrew_python" ] && "$homebrew_python" -c 'import tomllib' &>/dev/null; then
                    PYTHON3_BIN="$homebrew_python"
                    return
                fi
            done
        fi
    fi

    if command -v python3 &>/dev/null; then
        PYTHON3_BIN=$(command -v python3)
        return
    fi

    echo "Error: Python 3 is required to install Codex settings." >&2
    echo "  Run Homebrew Bundle first or install python3 manually." >&2
    return 1
}

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

force_link() {
    local source="$1"
    local target="$2"

    if [ "$OS" = "mac" ]; then
        ln -sfh "$source" "$target"
    else
        ln -sf "$source" "$target"
    fi
}

preflight_claude_component() {
    local source
    local target
    local directory
    local hook
    local hook_glob
    local settings_source

    case "$OS" in
        wsl|mac)
            ;;
        *)
            fail "Claude Code is unsupported on detected OS: $OS"
            return 1
            ;;
    esac

    for source in \
        "$DOTFILES_DIR/claude/CLAUDE.md" \
        "$DOTFILES_DIR/claude/keybindings.json" \
        "$DOTFILES_DIR/claude/agents/researcher.md" \
        "$DOTFILES_DIR/claude/agents/reviewer.md" \
        "$DOTFILES_DIR/claude/skills/fix-issue/SKILL.md" \
        "$DOTFILES_DIR/claude/skills/review-pr/SKILL.md" \
        "$DOTFILES_DIR/claude/skills/skill-creator/SKILL.md" \
        "$DOTFILES_DIR/claude/skills/skill-creator/references/guide.md"; do
        require_source_file "$source" || return 1
    done

    for directory in \
        "$CLAUDE_DIR" \
        "$HOOKS_DIR" \
        "$CLAUDE_DIR/agents" \
        "$CLAUDE_DIR/skills" \
        "$CLAUDE_DIR/skills/fix-issue" \
        "$CLAUDE_DIR/skills/review-pr" \
        "$CLAUDE_DIR/skills/skill-creator" \
        "$CLAUDE_DIR/skills/skill-creator/references" \
        "$HOME/.aws"; do
        validate_managed_directory "$directory" || return 1
    done

    for target in \
        "$CLAUDE_DIR/CLAUDE.md" \
        "$CLAUDE_DIR/keybindings.json" \
        "$CLAUDE_DIR/agents/researcher.md" \
        "$CLAUDE_DIR/agents/reviewer.md" \
        "$CLAUDE_DIR/skills/fix-issue/SKILL.md" \
        "$CLAUDE_DIR/skills/review-pr/SKILL.md" \
        "$CLAUDE_DIR/skills/skill-creator/SKILL.md" \
        "$CLAUDE_DIR/skills/skill-creator/references/guide.md" \
        "$CLAUDE_DIR/settings.json"; do
        validate_managed_target "$target" || return 1
    done

    if [ "$OS" = "wsl" ]; then
        hook_glob="$DOTFILES_DIR/claude/hooks/wsl/"
        settings_source="$DOTFILES_DIR/claude/settings/wsl.json"
        require_source_file "$settings_source" || return 1
        require_command git || return 1
        if ! git --version >/dev/null 2>&1; then
            fail "git is unavailable; install or repair Git before selecting Claude"
            return 1
        fi
        preflight_global_git_config || return 1
        require_command bwrap || return 1
        require_command socat || return 1
        require_command npm || return 1

        local npm_global
        if ! npm_global=$(npm root -g 2>/dev/null) || [ -z "$npm_global" ]; then
            fail "npm root -g failed; install Node.js before selecting Claude"
            return 1
        fi

        if [ ! -d "$npm_global/@anthropic-ai/sandbox-runtime" ]; then
            fail "@anthropic-ai/sandbox-runtime is not installed; install it before selecting Claude"
            return 1
        fi
    else
        hook_glob="$DOTFILES_DIR/claude/hooks/mac/"
        settings_source="$DOTFILES_DIR/claude/settings/mac.json"
        require_source_file "$settings_source" || return 1
    fi

    shopt -s nullglob
    for hook in "${hook_glob}"*.sh "$DOTFILES_DIR/claude/hooks/common/"*.sh; do
        if ! require_source_file "$hook" || ! validate_managed_target "$HOOKS_DIR/$(basename "$hook")"; then
            shopt -u nullglob
            return 1
        fi
    done
    shopt -u nullglob
}

install_claude_component() {
    if [ "$OS" = "wsl" ]; then
        git config --global core.sshCommand ssh.exe
    fi

    mkdir -p "$CLAUDE_DIR/hooks" "$CLAUDE_DIR/agents" \
        "$CLAUDE_DIR/skills/fix-issue" "$CLAUDE_DIR/skills/review-pr" \
        "$CLAUDE_DIR/skills/skill-creator/references" "$HOME/.aws"

    force_link "$DOTFILES_DIR/claude/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
    force_link "$DOTFILES_DIR/claude/keybindings.json" "$CLAUDE_DIR/keybindings.json"
    force_link "$DOTFILES_DIR/claude/agents/researcher.md" "$CLAUDE_DIR/agents/researcher.md"
    force_link "$DOTFILES_DIR/claude/agents/reviewer.md" "$CLAUDE_DIR/agents/reviewer.md"
    force_link "$DOTFILES_DIR/claude/skills/fix-issue/SKILL.md" "$CLAUDE_DIR/skills/fix-issue/SKILL.md"
    force_link "$DOTFILES_DIR/claude/skills/review-pr/SKILL.md" "$CLAUDE_DIR/skills/review-pr/SKILL.md"
    force_link "$DOTFILES_DIR/claude/skills/skill-creator/SKILL.md" "$CLAUDE_DIR/skills/skill-creator/SKILL.md"
    force_link "$DOTFILES_DIR/claude/skills/skill-creator/references/guide.md" "$CLAUDE_DIR/skills/skill-creator/references/guide.md"

    local hook_glob
    local settings_source
    case "$OS" in
        wsl)
            hook_glob="$DOTFILES_DIR/claude/hooks/wsl/"
            settings_source="$DOTFILES_DIR/claude/settings/wsl.json"
            ;;
        mac)
            hook_glob="$DOTFILES_DIR/claude/hooks/mac/"
            settings_source="$DOTFILES_DIR/claude/settings/mac.json"
            ;;
    esac

    shopt -s nullglob
    local hook
    for hook in "${hook_glob}"*.sh "$DOTFILES_DIR/claude/hooks/common/"*.sh; do
        force_link "$hook" "$HOOKS_DIR/$(basename "$hook")"
        chmod +x "$hook"
    done
    shopt -u nullglob

    local temporary_settings
    temporary_settings=$(mktemp "$CLAUDE_DIR/settings.json.XXXXXX")
    sed "s|__HOOKS_DIR__|$HOOKS_DIR|g" "$settings_source" > "$temporary_settings"
    mv "$temporary_settings" "$CLAUDE_DIR/settings.json"

    echo "Done! Claude Code dotfiles installed to $CLAUDE_DIR"
}

run_codex_config_merge() {
    local mode="$1"

    if ! resolve_python3; then
        return 1
    fi

    "$PYTHON3_BIN" - "$mode" <<'PYEOF'
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

mode = sys.argv[1]
config_path = os.path.join(os.path.expanduser("~"), ".codex", "config.toml")

defaults = {
    "sandbox_mode": "workspace-write",
    "approval_policy": "on-request",
    "features": {
        "hooks": True,
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
            "Codex config merge requires Python 3.11+ or the tomli package. "
            "Run Homebrew Bundle first or install tomli for the selected Python."
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
    features = existing.get("features")
    if isinstance(features, dict) and "codex_hooks" in features:
        if "hooks" not in features:
            features["hooks"] = features["codex_hooks"]
        del features["codex_hooks"]
    merged = existing.copy()
    merge_defaults(merged, defaults)
    validate_value([], merged)
except (RuntimeError, ValueError) as exc:
    print(f"Error: {exc}", file=sys.stderr)
    sys.exit(1)

if mode == "validate":
    print("  config.toml preflight passed")
    sys.exit(0)

if mode != "merge":
    print(f"Error: unsupported config merge mode: {mode}", file=sys.stderr)
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

validate_codex_config() {
    run_codex_config_merge validate
}

merge_codex_config() {
    run_codex_config_merge merge
}

preflight_codex_skills() {
    "$PYTHON3_BIN" - "$DOTFILES_DIR/codex/skills" "$AGENTS_SKILLS_DIR" <<'PYEOF'
import os
import sys

skills_source, skills_target = sys.argv[1:]
for skill_name in sorted(os.listdir(skills_source)):
    skill_dir = os.path.join(skills_source, skill_name)
    if not os.path.isdir(skill_dir):
        continue
    target = os.path.join(skills_target, skill_name)
    if os.path.lexists(target) and not os.path.islink(target):
        print(
            f"Error: existing Codex skill is not a symlink: {target}",
            file=sys.stderr,
        )
        sys.exit(1)
PYEOF
}

sync_codex_skills() {
    "$PYTHON3_BIN" - "$DOTFILES_DIR/codex/skills" "$AGENTS_SKILLS_DIR" <<'PYEOF'
import os
import sys

skills_source, skills_target = sys.argv[1:]
os.makedirs(skills_target, exist_ok=True)
for skill_name in sorted(os.listdir(skills_source)):
    skill_dir = os.path.join(skills_source, skill_name)
    if not os.path.isdir(skill_dir):
        continue
    target = os.path.join(skills_target, skill_name)
    if os.path.lexists(target):
        if not os.path.islink(target):
            raise RuntimeError(f"existing Codex skill is not a symlink: {target}")
        os.unlink(target)
    os.symlink(skill_dir, target)
    print(f"  skill: {skill_name}")
PYEOF
}

preflight_codex_component() {
    local source
    local agent
    local target
    local directory
    local hook

    case "$OS" in
        wsl|mac)
            ;;
        *)
            fail "Codex is unsupported on detected OS: $OS"
            return 1
            ;;
    esac

    if [ "$OS" = "wsl" ]; then
        require_command bwrap || return 1
    fi

    for directory in \
        "$CODEX_DIR" \
        "$CODEX_HOOKS_DIR" \
        "$CODEX_DIR/agents" \
        "$HOME/.agents" \
        "$AGENTS_SKILLS_DIR"; do
        validate_managed_directory "$directory" || return 1
    done

    for target in \
        "$CODEX_DIR/AGENTS.md" \
        "$CODEX_DIR/hooks.json"; do
        validate_managed_target "$target" || return 1
    done
    validate_regular_file_target "$CODEX_DIR/config.toml" || return 1
    validate_regular_file_target "$CODEX_DIR/config.toml.bak" || return 1

    for source in \
        "$DOTFILES_DIR/codex/AGENTS.md" \
        "$DOTFILES_DIR/codex/hooks.json.template" \
        "$DOTFILES_DIR/claude/hooks/common/block-rm-rf.sh"; do
        require_source_file "$source" || return 1
    done

    shopt -s nullglob
    for agent in "$DOTFILES_DIR/codex/agents/"*.toml; do
        if ! require_source_file "$agent" || ! validate_managed_target "$CODEX_DIR/agents/$(basename "$agent")"; then
            shopt -u nullglob
            return 1
        fi
    done
    for hook in "$DOTFILES_DIR/codex/hooks/$OS/"*.sh \
                "$DOTFILES_DIR/codex/hooks/common/"*.sh \
                "$DOTFILES_DIR/claude/hooks/common/block-rm-rf.sh"; do
        if ! require_source_file "$hook" || ! validate_managed_target "$CODEX_HOOKS_DIR/$(basename "$hook")"; then
            shopt -u nullglob
            return 1
        fi
    done
    shopt -u nullglob

    resolve_python3 || return 1
    validate_codex_config || return 1
    preflight_codex_skills || return 1
}

install_codex_component() {
    mkdir -p "$CODEX_HOOKS_DIR" "$CODEX_DIR/agents" "$AGENTS_SKILLS_DIR"

    force_link "$DOTFILES_DIR/codex/AGENTS.md" "$CODEX_DIR/AGENTS.md"

    local agent
    shopt -s nullglob
    for agent in "$DOTFILES_DIR/codex/agents/"*.toml; do
        force_link "$agent" "$CODEX_DIR/agents/$(basename "$agent")"
    done
    shopt -u nullglob

    sync_codex_skills

    local hook
    shopt -s nullglob
    for hook in "$DOTFILES_DIR/codex/hooks/$OS/"*.sh \
                "$DOTFILES_DIR/codex/hooks/common/"*.sh \
                "$DOTFILES_DIR/claude/hooks/common/block-rm-rf.sh"; do
        force_link "$hook" "$CODEX_HOOKS_DIR/$(basename "$hook")"
        chmod +x "$hook"
    done
    shopt -u nullglob

    local temporary_hooks
    temporary_hooks=$(mktemp "$CODEX_DIR/hooks.json.XXXXXX")
    sed "s|__HOOKS_DIR__|$CODEX_HOOKS_DIR|g" \
        "$DOTFILES_DIR/codex/hooks.json.template" > "$temporary_hooks"
    mv "$temporary_hooks" "$CODEX_DIR/hooks.json"

    merge_codex_config
    echo "Done! Codex dotfiles installed to $CODEX_DIR"
}

configure_shell_component() {
    case "$OS" in
        wsl)
            SHELL_SOURCES=(
                "$DOTFILES_DIR/fish/config.fish"
                "$DOTFILES_DIR/starship/starship.toml"
                "$DOTFILES_DIR/fish/wsl-abbreviations.fish"
            )
            SHELL_TARGETS=(
                "$HOME/.config/fish/config.fish"
                "$HOME/.config/starship.toml"
                "$HOME/.config/fish/wsl-abbreviations.fish"
            )
            SHELL_BACKUP_NAMES=(
                "fish/config.fish"
                "starship/starship.toml"
                "fish/wsl-abbreviations.fish"
            )
            ;;
        mac)
            SHELL_SOURCES=(
                "$DOTFILES_DIR/fish/config.fish"
                "$DOTFILES_DIR/starship/starship.toml"
                "$DOTFILES_DIR/starship/starship-terminal.toml"
                "$DOTFILES_DIR/ghostty/config"
            )
            SHELL_TARGETS=(
                "$HOME/.config/fish/config.fish"
                "$HOME/.config/starship.toml"
                "$HOME/.config/starship-terminal.toml"
                "$HOME/.config/ghostty/config"
            )
            SHELL_BACKUP_NAMES=(
                "fish/config.fish"
                "starship/starship.toml"
                "starship/starship-terminal.toml"
                "ghostty/config"
            )
            ;;
        *)
            fail "shell settings are unsupported on detected OS: $OS"
            return 1
            ;;
    esac
}

preflight_shell_component() {
    configure_shell_component || return 1
    require_command fish || return 1
    require_command starship || return 1
    validate_managed_directory "$HOME/.config" || return 1

    local index
    for index in "${!SHELL_TARGETS[@]}"; do
        require_source_file "${SHELL_SOURCES[$index]}" || return 1
        validate_managed_directory "$(dirname "${SHELL_TARGETS[$index]}")" || return 1
        validate_managed_target "${SHELL_TARGETS[$index]}" || return 1
    done
}

rollback_shell_component() {
    if [ "$SHELL_TRANSACTION_ACTIVE" != true ]; then
        return
    fi

    echo "  shell install failed; restoring previous targets" >&2
    local rollback_failed=false
    local index
    for ((index=${#SHELL_LINK_ATTEMPTS[@]} - 1; index >= 0; index--)); do
        local target="${SHELL_LINK_ATTEMPTS[$index]}"
        if [ -L "$target" ] && ! unlink "$target"; then
            local has_backup=false
            local backup_index
            for backup_index in "${!SHELL_BACKUP_TARGETS[@]}"; do
                if [ "${SHELL_BACKUP_TARGETS[$backup_index]}" = "$target" ]; then
                    has_backup=true
                    break
                fi
            done
            if [ "$has_backup" = false ]; then
                echo "Error: failed to remove new link during rollback: $target" >&2
                rollback_failed=true
            fi
        fi
    done
    for ((index=${#SHELL_BACKUP_TARGETS[@]} - 1; index >= 0; index--)); do
        local target="${SHELL_BACKUP_TARGETS[$index]}"
        local backup="${SHELL_BACKUP_SOURCES[$index]}"
        if [ -e "$backup" ] || [ -L "$backup" ]; then
            if [ -e "$target" ] || [ -L "$target" ]; then
                echo "Error: target exists during shell rollback: $target" >&2
                rollback_failed=true
            elif ! mkdir -p "$(dirname "$target")"; then
                echo "Error: failed to recreate target directory during rollback: $target" >&2
                rollback_failed=true
            elif ! mv "$backup" "$target"; then
                echo "Error: failed to restore backup during rollback: $backup -> $target" >&2
                rollback_failed=true
            fi
        elif [ ! -e "$target" ] && [ ! -L "$target" ]; then
            echo "Error: backup disappeared during rollback: $backup" >&2
            rollback_failed=true
        fi
    done
    SHELL_TRANSACTION_ACTIVE=false

    if [ "$rollback_failed" = true ]; then
        echo "Error: shell rollback did not complete. Recover the remaining backup paths manually:" >&2
        for index in "${!SHELL_BACKUP_SOURCES[@]}"; do
            if [ -e "${SHELL_BACKUP_SOURCES[$index]}" ] || [ -L "${SHELL_BACKUP_SOURCES[$index]}" ]; then
                echo "  ${SHELL_BACKUP_SOURCES[$index]} -> ${SHELL_BACKUP_TARGETS[$index]}" >&2
            fi
        done
        return 1
    fi
}

handle_shell_interruption() {
    if ! rollback_shell_component; then
        exit 1
    fi
    exit 1
}

finish_failed_shell_component() {
    if ! rollback_shell_component; then
        trap - HUP INT TERM
        return 1
    fi
    trap - HUP INT TERM
}

install_shell_component() {
    configure_shell_component
    SHELL_LINK_ATTEMPTS=()
    SHELL_BACKUP_TARGETS=()
    SHELL_BACKUP_SOURCES=()
    SHELL_TRANSACTION_ACTIVE=true
    trap 'handle_shell_interruption "$?"' HUP INT TERM

    local index
    local needs_backup=false
    local source
    local target
    local backup

    for index in "${!SHELL_TARGETS[@]}"; do
        if ! mkdir -p "$(dirname "${SHELL_TARGETS[$index]}")"; then
            finish_failed_shell_component || return 1
            return 1
        fi
        source="${SHELL_SOURCES[$index]}"
        target="${SHELL_TARGETS[$index]}"
        if ! { [ -L "$target" ] && [ -e "$target" ] && [ "$source" -ef "$target" ]; }; then
            if [ -e "$target" ] || [ -L "$target" ]; then
                needs_backup=true
            fi
        fi
    done

    if [ "$needs_backup" = true ] && ! ensure_dotfiles_backup_dir; then
        finish_failed_shell_component || return 1
        return 1
    fi

    for index in "${!SHELL_TARGETS[@]}"; do
        source="${SHELL_SOURCES[$index]}"
        target="${SHELL_TARGETS[$index]}"
        if [ -L "$target" ] && [ -e "$target" ] && [ "$source" -ef "$target" ]; then
            echo "  unchanged: $target"
            continue
        fi

        if [ -e "$target" ] || [ -L "$target" ]; then
            backup="$DOTFILES_BACKUP_DIR/${SHELL_BACKUP_NAMES[$index]}"
            SHELL_BACKUP_TARGETS+=("$target")
            SHELL_BACKUP_SOURCES+=("$backup")
            if ! mkdir -p "$(dirname "$backup")" || ! mv "$target" "$backup"; then
                finish_failed_shell_component || return 1
                return 1
            fi
            echo "  backed up: $target -> $backup"
        fi

        SHELL_LINK_ATTEMPTS+=("$target")
        if ! ln -s "$source" "$target"; then
            finish_failed_shell_component || return 1
            return 1
        fi
        echo "  linked: $target -> $source"
    done

    SHELL_TRANSACTION_ACTIVE=false
    trap - HUP INT TERM
    echo "Done! shell settings installed for $OS"
}

preflight_selected_components() {
    if [ "$INSTALL_CLAUDE" = true ]; then
        preflight_claude_component || return 1
    fi
    if [ "$INSTALL_CODEX" = true ]; then
        preflight_codex_component || return 1
    fi
    if [ "$INSTALL_SHELL" = true ]; then
        preflight_shell_component || return 1
    fi
}

main() {
    parse_components "$@" || exit 1
    OS=$(detect_os)
    echo "Detected OS: $OS"

    preflight_selected_components || exit 1

    if [ "$INSTALL_CLAUDE" = true ]; then
        install_claude_component
    fi
    if [ "$INSTALL_CODEX" = true ]; then
        install_codex_component
    fi
    if [ "$INSTALL_SHELL" = true ]; then
        install_shell_component
    fi
}

main "$@"
