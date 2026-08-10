#!/bin/bash
set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALLER="$DOTFILES_DIR/install.sh"
: "${TEST_ROOT:?Set TEST_ROOT to an empty temporary directory before running this test.}"

if [ ! -d "$TEST_ROOT" ] || [ -n "$(find "$TEST_ROOT" -mindepth 1 -print -quit)" ]; then
    echo "Error: TEST_ROOT must be an empty directory: $TEST_ROOT" >&2
    exit 1
fi

assert_absent() {
    if [ -e "$1" ] || [ -L "$1" ]; then
        echo "Assertion failed: expected absent: $1" >&2
        exit 1
    fi
}

assert_symlink() {
    if [ ! -L "$1" ] || [ "$(readlink "$1")" != "$2" ]; then
        echo "Assertion failed: expected symlink: $1 -> $2" >&2
        exit 1
    fi
}

expect_component_error() {
    local spec="$1"
    local home="$TEST_ROOT/parser-${spec//,/--}"

    if HOME="$home" GIT_CONFIG_GLOBAL="$home/gitconfig" bash "$INSTALLER" --components "$spec" >/dev/null 2>&1; then
        echo "Assertion failed: expected parser error: $spec" >&2
        exit 1
    fi
    assert_absent "$home/.claude"
    assert_absent "$home/.codex"
    assert_absent "$home/.config"
}

run_parser_tests() {
    expect_component_error ""
    expect_component_error "codex,"
    expect_component_error "codex,codex"
    expect_component_error "unknown"
}

run_wsl_success_test() {
    local home="$TEST_ROOT/wsl-success"
    local backup_dir

    mkdir -p "$home/.config/fish"
    printf '%s\n' 'echo original-fish' > "$home/.config/fish/config.fish"
    printf '%s\n' 'format = "original-starship"' > "$home/.config/starship.toml"

    HOME="$home" GIT_CONFIG_GLOBAL="$home/gitconfig" bash "$INSTALLER" --components codex,shell

    assert_absent "$home/.claude"
    assert_absent "$home/.aws"
    assert_absent "$home/gitconfig"
    assert_symlink "$home/.config/fish/config.fish" "$DOTFILES_DIR/fish/config.fish"
    assert_symlink "$home/.config/fish/wsl-abbreviations.fish" "$DOTFILES_DIR/fish/wsl-abbreviations.fish"
    assert_symlink "$home/.config/starship.toml" "$DOTFILES_DIR/starship/starship.toml"
    assert_symlink "$home/.codex/AGENTS.md" "$DOTFILES_DIR/codex/AGENTS.md"
    assert_symlink "$home/.agents/skills/fix-issue" "$DOTFILES_DIR/codex/skills/fix-issue"

    backup_dir=$(find "$home/.dotfiles-backups" -mindepth 1 -maxdepth 1 -type d -print -quit)
    test -n "$backup_dir"
    grep -qx 'echo original-fish' "$backup_dir/fish/config.fish"
    grep -qx 'format = "original-starship"' "$backup_dir/starship/starship.toml"
}

run_codex_preflight_test() {
    local home="$TEST_ROOT/codex-preflight"

    mkdir -p "$home/.codex"
    printf '%s\n' '[features]' 'unsupported = [{ name = "value" }]' > "$home/.codex/config.toml"

    if HOME="$home" GIT_CONFIG_GLOBAL="$home/gitconfig" bash "$INSTALLER" --components codex >/dev/null 2>&1; then
        echo "Assertion failed: expected unsupported TOML to stop Codex preflight" >&2
        exit 1
    fi
    assert_absent "$home/.codex/AGENTS.md"
    assert_absent "$home/.codex/hooks"
    assert_absent "$home/.agents"
    assert_absent "$home/.codex/config.toml.bak"
}

run_codex_bwrap_preflight_test() {
    local home="$TEST_ROOT/codex-without-bwrap"
    local fake_bin="$TEST_ROOT/no-bwrap-bin"
    local output="$TEST_ROOT/codex-without-bwrap-output.txt"
    local command_name

    mkdir -p "$fake_bin"
    for command_name in dirname grep; do
        ln -s "$(command -v "$command_name")" "$fake_bin/$command_name"
    done

    if HOME="$home" GIT_CONFIG_GLOBAL="$home/gitconfig" PATH="$fake_bin" \
        /bin/bash "$INSTALLER" --components codex > "$output" 2>&1; then
        echo "Assertion failed: expected missing bwrap to stop Codex preflight" >&2
        exit 1
    fi
    assert_absent "$home/.codex"
    assert_absent "$home/.agents"
    grep -Fq 'Error: required command is unavailable: bwrap' "$output"
}

run_claude_directory_target_preflight_test() {
    local home="$TEST_ROOT/claude-directory-target"

    mkdir -p "$home/.claude/CLAUDE.md"

    if HOME="$home" GIT_CONFIG_GLOBAL="$home/gitconfig" \
        bash "$INSTALLER" --components claude >/dev/null 2>&1; then
        echo "Assertion failed: expected Claude directory target to stop preflight" >&2
        exit 1
    fi
    assert_absent "$home/.claude/CLAUDE.md/CLAUDE.md"
    assert_absent "$home/.aws"
}

run_claude_git_preflight_test() {
    local home="$TEST_ROOT/claude-without-git"
    local fake_bin="$TEST_ROOT/no-git-bin"

    mkdir -p "$fake_bin"
    printf '%s\n' '#!/bin/bash' 'exit 1' > "$fake_bin/git"
    chmod +x "$fake_bin/git"

    if PATH="$fake_bin:$PATH" HOME="$home" GIT_CONFIG_GLOBAL="$home/gitconfig" \
        bash "$INSTALLER" --components claude >/dev/null 2>&1; then
        echo "Assertion failed: expected unavailable Git to stop Claude preflight" >&2
        exit 1
    fi
    assert_absent "$home/.claude"
    assert_absent "$home/.aws"
}

run_claude_git_config_preflight_test() {
    local home="$TEST_ROOT/claude-unreadable-git-config"

    mkdir -p "$home/gitconfig"

    if HOME="$home" GIT_CONFIG_GLOBAL="$home/gitconfig" \
        bash "$INSTALLER" --components claude >/dev/null 2>&1; then
        echo "Assertion failed: expected unreadable global Git config to stop Claude preflight" >&2
        exit 1
    fi
    assert_absent "$home/.claude"
    assert_absent "$home/.aws"
}

run_claude_readonly_git_config_preflight_test() {
    local home="$TEST_ROOT/claude-readonly-git-config"
    local output="$TEST_ROOT/claude-readonly-git-config-output.txt"

    mkdir -p "$home"
    printf '%s\n' '[core]' 'editor = vim' > "$home/gitconfig"
    chmod a-w "$home/gitconfig"

    if HOME="$home" GIT_CONFIG_GLOBAL="$home/gitconfig" \
        bash "$INSTALLER" --components claude > "$output" 2>&1; then
        echo "Assertion failed: expected readonly Git config to stop Claude preflight" >&2
        exit 1
    fi
    assert_absent "$home/.claude"
    assert_absent "$home/.aws"
    grep -Fq "Error: global Git config is not writable: $home/gitconfig" "$output"
}

run_claude_unwritable_git_config_parent_preflight_test() {
    local home="$TEST_ROOT/claude-unwritable-git-config-parent"
    local config_parent="$home/readonly"
    local output="$TEST_ROOT/claude-unwritable-git-config-parent-output.txt"

    mkdir -p "$config_parent"
    chmod a-w "$config_parent"

    if HOME="$home" GIT_CONFIG_GLOBAL="$config_parent/gitconfig" \
        bash "$INSTALLER" --components claude > "$output" 2>&1; then
        echo "Assertion failed: expected unwritable Git config parent to stop Claude preflight" >&2
        exit 1
    fi
    assert_absent "$home/.claude"
    assert_absent "$home/.aws"
    grep -Fq "Error: global Git config parent is not a writable real directory: $config_parent" "$output"
}

run_claude_existing_git_config_unwritable_parent_preflight_test() {
    local home="$TEST_ROOT/claude-existing-git-config-unwritable-parent"
    local config_parent="$home/readonly"
    local config_path="$config_parent/gitconfig"
    local output="$TEST_ROOT/claude-existing-git-config-unwritable-parent-output.txt"

    mkdir -p "$config_parent"
    printf '%s\n' '[core]' 'editor = vim' > "$config_path"
    chmod a-w "$config_parent"

    if HOME="$home" GIT_CONFIG_GLOBAL="$config_path" \
        bash "$INSTALLER" --components claude > "$output" 2>&1; then
        echo "Assertion failed: expected existing Git config with unwritable parent to stop Claude preflight" >&2
        exit 1
    fi
    assert_absent "$home/.claude"
    assert_absent "$home/.aws"
    grep -Fq "Error: global Git config parent is not a writable real directory: $config_parent" "$output"
}

run_claude_missing_git_config_parent_preflight_test() {
    local home="$TEST_ROOT/claude-missing-git-config-parent"
    local config_parent="$home/missing"
    local output="$TEST_ROOT/claude-missing-git-config-parent-output.txt"

    mkdir -p "$home"

    if HOME="$home" GIT_CONFIG_GLOBAL="$config_parent/gitconfig" \
        bash "$INSTALLER" --components claude > "$output" 2>&1; then
        echo "Assertion failed: expected missing Git config parent to stop Claude preflight" >&2
        exit 1
    fi
    assert_absent "$home/.claude"
    assert_absent "$home/.aws"
    grep -Fq "Error: global Git config parent is not a writable real directory: $config_parent" "$output"
}

run_claude_git_config_symlink_preflight_test() {
    local home="$TEST_ROOT/claude-git-config-symlink"
    local external_config="$TEST_ROOT/claude-git-config-symlink-external"
    local config_path="$home/gitconfig"
    local output="$TEST_ROOT/claude-git-config-symlink-output.txt"

    mkdir -p "$home"
    printf '%s\n' '[core]' 'editor = vim' > "$external_config"
    ln -s "$external_config" "$config_path"

    if HOME="$home" GIT_CONFIG_GLOBAL="$config_path" \
        bash "$INSTALLER" --components claude > "$output" 2>&1; then
        echo "Assertion failed: expected Git config symlink to stop Claude preflight" >&2
        exit 1
    fi
    assert_absent "$home/.claude"
    assert_absent "$home/.aws"
    assert_symlink "$config_path" "$external_config"
    grep -Fq "Error: global Git config is not a regular file: $config_path" "$output"
}

run_codex_directory_target_preflight_test() {
    local home="$TEST_ROOT/codex-directory-target"

    mkdir -p "$home/.codex/AGENTS.md"

    if HOME="$home" GIT_CONFIG_GLOBAL="$home/gitconfig" \
        bash "$INSTALLER" --components codex >/dev/null 2>&1; then
        echo "Assertion failed: expected Codex directory target to stop preflight" >&2
        exit 1
    fi
    assert_absent "$home/.codex/AGENTS.md/AGENTS.md"
    assert_absent "$home/.codex/hooks"
    assert_absent "$home/.agents"
}

run_codex_backup_directory_preflight_test() {
    local home="$TEST_ROOT/codex-backup-directory"

    mkdir -p "$home/.codex/config.toml.bak"
    printf '%s\n' 'sandbox_mode = "workspace-write"' > "$home/.codex/config.toml"

    if HOME="$home" GIT_CONFIG_GLOBAL="$home/gitconfig" \
        bash "$INSTALLER" --components codex >/dev/null 2>&1; then
        echo "Assertion failed: expected Codex backup directory to stop preflight" >&2
        exit 1
    fi
    grep -qx 'sandbox_mode = "workspace-write"' "$home/.codex/config.toml"
    assert_absent "$home/.codex/AGENTS.md"
    assert_absent "$home/.codex/hooks"
    assert_absent "$home/.agents"
}

run_codex_config_symlink_preflight_test() {
    local home="$TEST_ROOT/codex-config-symlink"
    local external_config="$TEST_ROOT/external-config.toml"

    printf '%s\n' 'sandbox_mode = "danger-full-access"' > "$external_config"
    mkdir -p "$home/.codex"
    ln -s "$external_config" "$home/.codex/config.toml"

    if HOME="$home" GIT_CONFIG_GLOBAL="$home/gitconfig" \
        bash "$INSTALLER" --components codex >/dev/null 2>&1; then
        echo "Assertion failed: expected Codex config symlink to stop preflight" >&2
        exit 1
    fi
    grep -qx 'sandbox_mode = "danger-full-access"' "$external_config"
    assert_symlink "$home/.codex/config.toml" "$external_config"
    assert_absent "$home/.codex/AGENTS.md"
    assert_absent "$home/.agents"
}

run_selected_component_preflight_test() {
    local home="$TEST_ROOT/selected-component-preflight"

    mkdir -p "$home/.config/starship.toml"

    if HOME="$home" GIT_CONFIG_GLOBAL="$home/gitconfig" \
        bash "$INSTALLER" --components codex,shell >/dev/null 2>&1; then
        echo "Assertion failed: expected shell directory target to stop all selected components" >&2
        exit 1
    fi
    assert_absent "$home/.codex"
    assert_absent "$home/.agents"
}

run_default_compatibility_test() {
    local home="$TEST_ROOT/default-all"
    local fake_bin="$TEST_ROOT/default-fake-bin"
    local fake_npm_root="$TEST_ROOT/default-npm-root"

    mkdir -p "$home" "$fake_bin" "$fake_npm_root/@anthropic-ai/sandbox-runtime"
    printf '%s\n' '[init]' 'defaultBranch = main' > "$home/.gitconfig"
    printf '%s\n' \
        '#!/bin/bash' \
        "if [ \"\$1\" = \"root\" ] && [ \"\$2\" = \"-g\" ]; then" \
        "    printf '%s\\n' \"\$FAKE_NPM_ROOT\"" \
        '    exit 0' \
        'fi' \
        'exit 1' > "$fake_bin/npm"
    chmod +x "$fake_bin/npm"

    PATH="$fake_bin:$PATH" FAKE_NPM_ROOT="$fake_npm_root" \
        HOME="$home" XDG_CONFIG_HOME="$home/.config" \
        env -u GIT_CONFIG_GLOBAL bash "$INSTALLER"

    test -e "$home/.claude/settings.json"
    test -d "$home/.aws"
    assert_symlink "$home/.codex/AGENTS.md" "$DOTFILES_DIR/codex/AGENTS.md"
    assert_symlink "$home/.config/fish/config.fish" "$DOTFILES_DIR/fish/config.fish"
    test "$(HOME="$home" XDG_CONFIG_HOME="$home/.config" env -u GIT_CONFIG_GLOBAL git config --global --get core.sshCommand)" = ssh.exe
}

run_wsl_rollback_test() {
    local home="$TEST_ROOT/wsl-rollback"
    local fake_bin="$TEST_ROOT/fake-bin"

    mkdir -p "$home/.config/fish" "$fake_bin"
    printf '%s\n' 'echo rollback-fish' > "$home/.config/fish/config.fish"
    printf '%s\n' 'format = "rollback-starship"' > "$home/.config/starship.toml"
    printf '%s\n' \
        '#!/bin/bash' \
        "for argument in \"\$@\"; do" \
        "    if [ \"\$argument\" = \"\${FAKE_LN_FAILURE_TARGET:-}\" ]; then exit 1; fi" \
        'done' \
        "exec /bin/ln \"\$@\"" > "$fake_bin/ln"
    chmod +x "$fake_bin/ln"

    if PATH="$fake_bin:$PATH" FAKE_LN_FAILURE_TARGET="$home/.config/starship.toml" \
        HOME="$home" GIT_CONFIG_GLOBAL="$home/gitconfig" \
        bash "$INSTALLER" --components shell >/dev/null 2>&1; then
        echo "Assertion failed: expected shell link failure" >&2
        exit 1
    fi

    test ! -L "$home/.config/fish/config.fish"
    test ! -L "$home/.config/starship.toml"
    assert_absent "$home/.config/fish/wsl-abbreviations.fish"
    grep -qx 'echo rollback-fish' "$home/.config/fish/config.fish"
    grep -qx 'format = "rollback-starship"' "$home/.config/starship.toml"
}

run_wsl_rollback_failure_test() {
    local home="$TEST_ROOT/wsl-rollback-failure"
    local fake_bin="$TEST_ROOT/rollback-failure-bin"
    local output="$TEST_ROOT/rollback-failure-output.txt"
    local backup_dir

    mkdir -p "$home/.config/fish" "$fake_bin"
    printf '%s\n' 'echo rollback-failure-fish' > "$home/.config/fish/config.fish"
    printf '%s\n' 'format = "rollback-failure-starship"' > "$home/.config/starship.toml"
    printf '%s\n' \
        '#!/bin/bash' \
        "for argument in \"\$@\"; do" \
        "    if [ \"\$argument\" = \"\${FAKE_LN_FAILURE_TARGET:-}\" ]; then exit 1; fi" \
        'done' \
        "exec $(command -v ln) \"\$@\"" > "$fake_bin/ln"
    printf '%s\n' \
        '#!/bin/bash' \
        "if [ \"\$1\" = \"\${FAKE_UNLINK_FAILURE_TARGET:-}\" ]; then exit 1; fi" \
        "exec $(command -v unlink) \"\$@\"" > "$fake_bin/unlink"
    printf '%s\n' \
        '#!/bin/bash' \
        "if [ \"\$2\" = \"\${FAKE_MV_FAILURE_TARGET:-}\" ]; then exit 1; fi" \
        "exec $(command -v mv) \"\$@\"" > "$fake_bin/mv"
    chmod +x "$fake_bin/ln" "$fake_bin/unlink" "$fake_bin/mv"

    if PATH="$fake_bin:$PATH" \
        FAKE_LN_FAILURE_TARGET="$home/.config/starship.toml" \
        FAKE_UNLINK_FAILURE_TARGET="$home/.config/fish/config.fish" \
        FAKE_MV_FAILURE_TARGET="$home/.config/fish/config.fish" \
        HOME="$home" GIT_CONFIG_GLOBAL="$home/gitconfig" \
        bash "$INSTALLER" --components shell > "$output" 2>&1; then
        echo "Assertion failed: expected incomplete shell rollback" >&2
        exit 1
    fi

    assert_symlink "$home/.config/fish/config.fish" "$DOTFILES_DIR/fish/config.fish"
    grep -qx 'format = "rollback-failure-starship"' "$home/.config/starship.toml"
    backup_dir=$(find "$home/.dotfiles-backups" -mindepth 1 -maxdepth 1 -type d -print -quit)
    test -n "$backup_dir"
    grep -qx 'echo rollback-failure-fish' "$backup_dir/fish/config.fish"
    grep -Fq 'Error: shell rollback did not complete.' "$output"
    grep -Fq "$backup_dir/fish/config.fish -> $home/.config/fish/config.fish" "$output"
}

run_wsl_signal_after_backup_test() {
    local home="$TEST_ROOT/wsl-signal-after-backup"
    local fake_bin="$TEST_ROOT/signal-after-backup-bin"
    local output="$TEST_ROOT/signal-after-backup-output.txt"
    local backup_dir

    mkdir -p "$home/.config/fish" "$fake_bin"
    printf '%s\n' 'echo signal-fish' > "$home/.config/fish/config.fish"
    printf '%s\n' 'format = "signal-starship"' > "$home/.config/starship.toml"
    printf '%s\n' \
        '#!/bin/bash' \
        'if [ "$1" = "${FAKE_MV_SIGNAL_TARGET:-}" ]; then' \
        "    $(command -v mv) \"\\$@\"" \
        '    kill -TERM "$PPID"' \
        '    exit 0' \
        'fi' \
        "exec $(command -v mv) \"\\$@\"" > "$fake_bin/mv"
    chmod +x "$fake_bin/mv"

    if PATH="$fake_bin:$PATH" \
        FAKE_MV_SIGNAL_TARGET="$home/.config/fish/config.fish" \
        HOME="$home" GIT_CONFIG_GLOBAL="$home/gitconfig" \
        bash "$INSTALLER" --components shell > "$output" 2>&1; then
        echo "Assertion failed: expected signal to interrupt shell install" >&2
        exit 1
    fi

    test ! -L "$home/.config/fish/config.fish"
    grep -qx 'echo signal-fish' "$home/.config/fish/config.fish"
    grep -qx 'format = "signal-starship"' "$home/.config/starship.toml"
    assert_absent "$home/.config/fish/wsl-abbreviations.fish"
    backup_dir=$(find "$home/.dotfiles-backups" -mindepth 1 -maxdepth 1 -type d -print -quit)
    test -n "$backup_dir"
    assert_absent "$backup_dir/fish/config.fish"
    grep -Fq 'shell install failed; restoring previous targets' "$output"
}

run_macos_default_compatibility_test() {
    local home="$TEST_ROOT/macos-default-all"
    local backup_dir

    mkdir -p "$home/.config/fish" "$home/.config/ghostty"
    printf '%s\n' 'echo original-fish' > "$home/.config/fish/config.fish"
    printf '%s\n' 'format = "original-starship"' > "$home/.config/starship.toml"
    printf '%s\n' 'format = "original-terminal-starship"' > "$home/.config/starship-terminal.toml"
    printf '%s\n' 'font-family = "original"' > "$home/.config/ghostty/config"

    HOME="$home" GIT_CONFIG_GLOBAL="$home/gitconfig" bash "$INSTALLER"

    test -e "$home/.claude/settings.json"
    test -d "$home/.aws"
    assert_symlink "$home/.codex/AGENTS.md" "$DOTFILES_DIR/codex/AGENTS.md"
    assert_symlink "$home/.config/fish/config.fish" "$DOTFILES_DIR/fish/config.fish"
    assert_symlink "$home/.config/starship.toml" "$DOTFILES_DIR/starship/starship.toml"
    assert_symlink "$home/.config/starship-terminal.toml" "$DOTFILES_DIR/starship/starship-terminal.toml"
    assert_symlink "$home/.config/ghostty/config" "$DOTFILES_DIR/ghostty/config"
    backup_dir=$(find "$home/.dotfiles-backups" -mindepth 1 -maxdepth 1 -type d -print -quit)
    test -n "$backup_dir"
    grep -qx 'font-family = "original"' "$backup_dir/ghostty/config"
}

run_parser_tests
run_codex_preflight_test
run_claude_directory_target_preflight_test
run_codex_directory_target_preflight_test
run_codex_backup_directory_preflight_test
run_codex_config_symlink_preflight_test
run_selected_component_preflight_test

case "$(uname -s)" in
    Darwin)
        run_macos_default_compatibility_test
        ;;
    Linux)
        if grep -qi microsoft /proc/version 2>/dev/null; then
            run_codex_bwrap_preflight_test
            run_claude_git_preflight_test
            run_claude_git_config_preflight_test
            run_claude_readonly_git_config_preflight_test
            run_claude_unwritable_git_config_parent_preflight_test
            run_claude_existing_git_config_unwritable_parent_preflight_test
            run_claude_missing_git_config_parent_preflight_test
            run_claude_git_config_symlink_preflight_test
            run_default_compatibility_test
            run_wsl_success_test
            run_wsl_rollback_test
            run_wsl_rollback_failure_test
            run_wsl_signal_after_backup_test
        else
            echo "Error: WSL integration tests require a WSL runner" >&2
            exit 1
        fi
        ;;
    *)
        echo "Error: unsupported test platform: $(uname -s)" >&2
        exit 1
        ;;
esac

echo "install component integration tests passed"
echo "TEST_ROOT is retained for inspection: $TEST_ROOT"
