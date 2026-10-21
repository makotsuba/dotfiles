# dotfiles

Personal dotfiles for Claude Code, Codex, Kiro CLI, fish, Starship, and related tooling.

These are opinionated settings maintained for the repository owner. Review the component scope, prerequisites, and safety notes before running the installer on another system. The installer changes only explicitly selected components.

## Supported Platforms

| Platform | Support |
| --- | --- |
| macOS (Apple Silicon) | Supported |
| WSL 2 (Ubuntu/Debian) | Supported |
| Linux (native Debian/Ubuntu) | Supported for all components; desktop notifications are optional. See [Linux verification](#linux-verification) for tested versions and architectures |

## Quick Start

The clone command below is intended for the repository owner and uses GitHub SSH authentication.

```bash
mkdir -p ~/src
git clone git@github.com:makotsuba/dotfiles.git ~/src/dotfiles
cd ~/src/dotfiles
```

On macOS, install the [macOS prerequisites](#macos) before applying the core configuration:

```bash
brew bundle install --no-upgrade --file ~/src/dotfiles/Brewfile
bash install.sh --components claude,codex,shell
```

Kiro steering is opt-in and can be installed independently:

```bash
bash install.sh --components kiro
```

On WSL 2 or native Linux, complete the [WSL prerequisites](#wsl-2-windows) or [Linux prerequisites](#native-linux-debianubuntu) before selecting the required components.

## Components

`--components` is required. Provide one or more comma-separated component names explicitly. Missing arguments, `all`, empty values, duplicate names, and unknown names fail before preflight checks or managed-path changes begin.

```bash
# Codex and shell configuration
bash install.sh --components codex,shell

# Kiro steering only
bash install.sh --components kiro

# Every available component
bash install.sh --components claude,codex,kiro,shell
```

| Component | Managed scope | Additional Linux/WSL requirements or effects |
| --- | --- | --- |
| `claude` | `~/.claude/`; validates or creates the `~/.aws/` directory without managing its contents | Linux/WSL require `bwrap` and `socat`. WSL additionally requires `ssh.exe` and `@anthropic-ai/sandbox-runtime`, and sets `core.sshCommand = ssh.exe`. Native Linux leaves global Git configuration unchanged |
| `codex` | `~/.codex/`, `~/.agents/skills/`, Codex hooks and merged configuration | Requires `bwrap` on Linux/WSL; validates Python and the existing `config.toml` structure on every supported OS |
| `kiro` | Global steering files under `~/.kiro/steering/global/` | No additional requirement; applied only when explicitly selected |
| `shell` | fish and Starship configuration | Requires fish and Starship; backs up managed targets before replacing them with symlinks |

The installer completes preflight checks for every selected component before installing any of them. If shell link creation fails, targets already changed by that shell-component run are restored from its backup when possible.

## Platform Prerequisites

### macOS

#### Homebrew

Install Homebrew, then check and install the core dependencies. `brew bundle check` exits non-zero when dependencies are missing; that is expected before the initial installation.

```bash
brew bundle check --no-upgrade --file ~/src/dotfiles/Brewfile
brew bundle install --no-upgrade --file ~/src/dotfiles/Brewfile
```

`--no-upgrade` prevents the Bundle from proactively running `brew upgrade` for outdated dependencies. A required `brew install` may still update dependencies. The core Bundle includes the Homebrew Python used when merging Codex configuration and `uv` for project and skill environments. Homebrew Python remains the bootstrap runtime; `uv` may reuse it when it satisfies a project's requirements.

#### cmux

cmux is optional and requires macOS 14 or later. For a new installation, use the separate Bundle:

```bash
brew bundle check --no-upgrade --file ~/src/dotfiles/Brewfile.cmux
brew bundle install --no-upgrade --file ~/src/dotfiles/Brewfile.cmux
```

If `/Applications/cmux.app` was installed outside Homebrew, do not run the Bundle first. Attempt a one-time adoption instead:

```bash
brew install --cask --adopt cmux
```

Adoption succeeds only when the existing app matches the cask artifact. If it fails, do not use `--force` or delete the app manually; leave the existing app in place and investigate the cause. After a successful adoption, verify registration with:

```bash
brew bundle check --no-upgrade --file ~/src/dotfiles/Brewfile.cmux
```

The cmux cask uses `auto_updates`, so routine updates are left to cmux. To explicitly ask Homebrew to check auto-updating casks, run:

```bash
brew upgrade --cask --greedy-auto-updates cmux
```

#### Shell and terminal

After running `bash install.sh --components shell`, verify that `/opt/homebrew/bin/fish` is registered in `/etc/shells` before making it the login shell:

```bash
chsh -s /opt/homebrew/bin/fish
```

Return to zsh with `chsh -s /bin/zsh`. In Terminal.app, select **Default login shell** under Settings > General > **Shells open with**, then set the font under Profiles > Text to `PlemolJP Console NF` at 15 pt.

The installer does not replace the complete VS Code user `settings.json`. Add only the required terminal settings to the existing file:

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

When cmux is installed, it reads `~/.config/ghostty/config`. This configuration selects `PlemolJP Console NF`; install that font first or Ghostty will use a fallback. Restart cmux or press `⌘⇧,` inside cmux after changing the configuration.

### WSL 2 (Windows)

#### Sandbox dependencies

The `codex` and `claude` components require `bubblewrap` and `jq` on WSL. Codex prefers the system `bwrap` in its Linux/WSL2 sandbox and also has a bundled fallback, but this setup follows the [OpenAI sandbox documentation](https://learn.chatgpt.com/docs/sandboxing) and requires the system package for reproducibility. The selected-component preflight stops before making changes when either dependency is unavailable.

```bash
sudo apt install -y bubblewrap jq
```

The `claude` component additionally requires `socat` and the Claude Code sandbox runtime:

```bash
sudo apt install -y socat
npm install -g @anthropic-ai/sandbox-runtime
```

On Ubuntu 24.04, unprivileged user-namespace restrictions may require the additional AppArmor configuration described in the [Claude Code sandbox documentation](https://code.claude.com/docs/en/sandboxing).

#### Notifications

Windows toast notifications require PowerShell 7 and BurntToast.

```powershell
winget install --id Microsoft.PowerShell --source winget
Install-Module -Name BurntToast -Force
```

#### Pre-migration shell audit

Before managing existing WSL shell settings, run the audit and review its output. It does not display setting values, symlink destinations, or `.env` contents.

```bash
sh ~/src/dotfiles/scripts/audit-wsl-shell.sh
```

Use `--details` to additionally list alias and abbreviation names and selected Starship environment-manager module names. Complex declarations are omitted without displaying their values. The Starship audit is limited to `direnv`, `conda`, `nix_shell`, `mise`, and `pixi`, plus pyenv, rbenv, nvm, asdf, and mise settings inside language modules.

```bash
sh ~/src/dotfiles/scripts/audit-wsl-shell.sh --details
```

#### Shell commands

After the audit, confirm that fish, Starship, and the Windows-side 1Password/OpenSSH commands are available:

```bash
command -v fish starship op.exe ssh.exe ssh-add.exe
cd ~/src/dotfiles
bash install.sh --components shell
```

The shell component skips the corresponding abbreviation when `op.exe`, `ssh.exe`, or `ssh-add.exe` is unavailable, leaving the Linux-side command unchanged for that abbreviation. The `claude` component is different: confirm that `ssh.exe` is available before selecting it because the installer sets `core.sshCommand = ssh.exe`. To install Codex with the shell configuration, run `bash install.sh --components codex,shell`.

The WSL shell component manages:

- `~/.config/fish/config.fish`
- `~/.config/fish/wsl-abbreviations.fish` for interactive WSL sessions
- `~/.config/starship.toml`

Set a Nerd Font such as `PlemolJP Console NF` in the host-side Windows Terminal profile. The installer does not change Windows Terminal or PowerShell settings, the default shell, or installed packages.

### Native Linux (Debian/Ubuntu)

All four components can be installed on native Linux, including headless servers and cloud development environments. The installer manages configuration files; it does not install Claude Code, Codex, Kiro CLI, packages, or the login shell.

#### Linux dependencies

Arrange installation of the packages required by the selected components before running the installer:

| Component | Prerequisites |
| --- | --- |
| `claude` | Bash, `jq`, `bubblewrap` (`bwrap`), `socat` |
| `codex` | Bash, `jq`, `bubblewrap`, Python 3.11+ or Python with `tomli` |
| `kiro` | Bash and standard file utilities |
| `shell` | fish and Starship |

Debian/Ubuntu package names include `jq`, `bubblewrap`, `socat`, `python3`, `python3-tomli`, `fish`, and `git`. Install Starship separately if the distribution does not package it. The optional `@anthropic-ai/sandbox-runtime` package supplies Claude Code's additional seccomp filter; native Linux installation does not require the global npm package.

Linux sandboxing also depends on usable user namespaces and the host's security policy. A `bwrap` executable being present does not prove that a cloud container permits sandbox creation. Follow the [OpenAI sandbox guidance](https://learn.chatgpt.com/docs/sandboxing) and [Claude Code Linux setup](https://code.claude.com/docs/en/sandboxing#set-up-linux-and-wsl2), including the AppArmor profile requirements on Ubuntu 24.04 where applicable. The installer does not change kernel or AppArmor settings. The Linux Claude configuration enables `sandbox.failIfUnavailable` and disables unsandboxed retries, so an unavailable sandbox stops client startup rather than silently weakening isolation. The explicit `docker` exclusion remains as in the macOS configuration.

#### Linux installation and notifications

```bash
bash install.sh --components claude,codex,kiro,shell
```

Linux shell installation manages only `~/.config/fish/config.fish` and `~/.config/starship.toml`. It leaves native Git SSH configuration unchanged and does not install WSL abbreviations or macOS terminal settings.

Desktop notifications optionally use `notify-send` from `libnotify-bin`. The hooks send only when `DISPLAY` or `WAYLAND_DISPLAY`, a session `DBUS_SESSION_BUS_ADDRESS`, and `notify-send` are available. Missing desktop services, missing notification tools, and delivery failures are silently ignored. A successful hook exit in a cloud or headless session means the hook completed; it does not confirm delivery. Security hooks remain active in headless sessions.

## Updating

On macOS, satisfy the core Bundle before rerunning the installer:

```bash
git pull
brew bundle install --no-upgrade --file ~/src/dotfiles/Brewfile
bash install.sh --components claude,codex,shell
```

On WSL or native Linux, recheck the prerequisites for the components being updated, then select the required combination explicitly:

```bash
# Claude, Codex, and shell
git pull && bash install.sh --components claude,codex,shell

# Codex and shell
git pull && bash install.sh --components codex,shell

# Kiro steering only
git pull && bash install.sh --components kiro
```

Restart the affected client after installation or an update.

## Backup and Rollback

Before changing shell targets, the installer moves existing regular files, symlinks to another source, and dangling symlinks into `~/.dotfiles-backups/fish-starship-*/`. It stops without changing anything when a managed file path contains a real directory.

To restore a target, use the backup directory printed by the installer. First verify that the current target symlink points to this dotfiles repository. Move only that target file aside, then restore the corresponding file from the backup. The complete backup directory does not need to be deleted.

If shell link creation is interrupted or fails, the installer attempts to roll back only the targets changed during that shell-component run. It reports any backup paths that still require manual recovery.

The Codex component merges missing defaults into an existing `~/.codex/config.toml` and saves the previous content as `~/.codex/config.toml.bak`. Unsupported structures stop the installer instead of being rewritten silently.

## Security Boundaries

Claude Code and Codex use supplementary safety guards. The installer requires `jq` before installing either component, and each guard fails closed if `jq` later becomes unavailable.

| Tool | Hook | Scope | Behavior |
| --- | --- | --- | --- |
| Claude Code | `block-dotenv.sh` | Read / Edit / Write / MultiEdit / NotebookEdit | Rejects direct access to `.env`, `.env.?*`, and `.envrc` |
| Claude Code | `block-rm-rf.sh` | Bash | Rejects `rm -rf` and `rm -fr` |
| Codex | `block-dotenv-bash.sh` | Bash | Rejects direct shell references to `.env`, `.env.?*`, and `.envrc` |
| Codex | `block-rm-rf.sh` | Bash | Rejects `rm -rf` and `rm -fr` |

> **Note:** Hooks are defense in depth, not a complete security boundary. Codex user hooks must be enabled and trusted before they run. The Codex `PreToolUse` hook is currently applied only to Bash, so its `.env` protection does not cover native file-tool equivalents. Use it together with sandbox permissions and the prohibition in `codex/AGENTS.md`.

This repository does not manage fish history or variables, completion caches, `.env*`, direnv data, AWS/SSH/1Password credentials, or Codex authentication, sessions, logs, caches, and memories. It also does not automatically modify the complete VS Code user `settings.json` or Terminal.app profiles.

## Verification

Run the full component integration suite on macOS, WSL, or native Linux with an explicitly created empty test root. The suite intentionally retains that directory for inspection. Native Linux runs the common checks and Linux-specific installation, component selection, reinstallation, dependency, configuration-preservation, and shell rollback tests, then exits zero on success. macOS and WSL run their own platform-specific cases.

```bash
TEST_ROOT=$(mktemp -d /tmp/dotfiles-install-test.XXXXXX)
TEST_ROOT="$TEST_ROOT" bash scripts/test-install-components.sh
```

Run the focused hook and status-line tests separately:

```bash
bash scripts/test-security-hooks.sh
bash scripts/test-statusline.sh
bash scripts/test-linux-notifications.sh
```

### Linux verification

The installer and focused tests were verified on Debian 13 and Ubuntu 24.04 arm64 virtual machines, as well as the macOS integration suite. On 2026-10-21, Codex Cloud validation of commit `9338ea3` also passed on Debian 13.6 x86_64: component integration, security hooks, statusline, and Linux notification mocks. Missing dependencies were extracted into a validation-only directory and supplied through command-local `PATH` and `LD_LIBRARY_PATH`; no system installation or default-home installer run was performed. Other Linux versions and architectures have not been verified. WSL-specific tests remain in the suite, but were not rerun for this change.

A separate `bwrap` smoke test confirmed read-only filesystem and network-namespace isolation on both Linux VMs. Ubuntu 24.04 required the official `bwrap-userns-restrict` AppArmor profile before that smoke test passed; the installer did not apply the profile.

In Codex Cloud, both user-namespace and network-namespace `bwrap` probes exited 1 with `bwrap: setting up uid map: Read-only file system`. Actual Cloud sandbox execution and filesystem/network isolation remain unverified. No namespace, mount, kernel, AppArmor, or other security controls were changed to bypass this restriction.

The Linux notification suite uses a mock command and does not send real desktop notifications. Installed notification hooks also completed quietly in the Cloud headless environment. Installer tests confirm configuration deployment, not live authenticated Claude Code, Codex, or Kiro hook dispatch, real desktop delivery, or WSL/Windows interoperability. Verify those separately in the target runtime.

## Installed Paths

### Claude Code

- `~/.claude/CLAUDE.md`
- `~/.claude/keybindings.json`
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

### Kiro CLI

- `~/.kiro/steering/global/default.md`
- `~/.kiro/steering/global/aws-infrastructure.md`

### Shell Prompt

#### macOS Paths

- `~/.config/fish/config.fish`
- `~/.config/starship.toml`
- `~/.config/starship-terminal.toml`
- `~/.config/ghostty/config`

#### WSL Paths

- `~/.config/fish/config.fish`
- `~/.config/fish/wsl-abbreviations.fish`
- `~/.config/starship.toml`

#### Linux Paths

- `~/.config/fish/config.fish`
- `~/.config/starship.toml`

## Codex Notes

- The `researcher` subagent is defined in `codex/agents/researcher.toml`. Pull request reviews are delegated to the built-in `review-agent` skill.
- Skills under `codex/skills/` are symlinked into `~/.agents/skills/`.
- `sandbox_mode = "workspace-write"` and `approval_policy = "on-request"` are explicit defaults, so new installations do not depend on upstream defaults for the low-friction sandbox policy.
- The installer preserves existing values in `~/.codex/config.toml` and adds only missing defaults. It enables `features.memories = true` by default and backs up the previous content to `~/.codex/config.toml.bak`.
- Codex stores memories in `~/.codex/memories/`. This is runtime data generated and updated by Codex and is not managed by the installer.
- Merging an existing `~/.codex/config.toml` requires Python's `tomllib`. Install `tomli` when using Python earlier than 3.11.
- If the existing `~/.codex/config.toml` contains an unsupported structure, such as an array of tables, the installer stops with an explicit error instead of rewriting it silently.
- Linux, WSL, and macOS configure a task-completion notification hook. Linux desktop delivery is optional. The Claude Code idle notification has not been ported to Codex.

## Kiro Notes

- Kiro CLI reads Markdown files below `~/.kiro/steering/` as global steering. This repository uses a `global/` subdirectory for organization.
- The front matter and conditional inclusion described here target the early-access [CLI 3.0 V3 engine](https://kiro.dev/docs/cli/v3/), currently enabled with `kiro-cli --v3`. Equivalent conditional inclusion behavior is not guaranteed with the legacy 2.x engine.
- [`default.md`](kiro/steering/global/default.md) uses [`inclusion: always`](https://kiro.dev/docs/steering/). [`aws-infrastructure.md`](kiro/steering/global/aws-infrastructure.md) uses `inclusion: auto`; Kiro includes it when the request semantically matches its front matter `description`. It can also be selected explicitly from the slash-command menu.
- According to the current [custom agent configuration reference](https://kiro.dev/docs/custom-agents/configuration-reference/), built-in agents always inherit default resources. Custom agents inherit them unless `chat.disableInheritingDefaultResources` is enabled. When inheritance is disabled, explicit `file://` resources become persistent context: add `default.md` to every custom agent that needs the common guidance, and add `aws-infrastructure.md` only to AWS-specific agents. Use `/context show` to verify active context.
- Kiro discovers `AGENTS.md` automatically. Automatic discovery of `CLAUDE.md` is not documented; add it explicitly as a `file://` resource when required.
- Keep always-included steering short and universal because it consumes context continuously. Put domain-specific guidance behind conditional inclusion.
- Keep `~/.kiro/steering/global/` as a real directory. The installer symlinks only the Markdown files and rejects a directory symlink because Kiro scans the directory.
- The installer targets the standard `~/.kiro` location and does not follow a `KIRO_HOME` override.
- `~/.kiro/settings/mcp.json` is not managed because it may contain machine-specific MCP server definitions and authentication settings. Store tokens in environment variables and reference them from `mcp.json` with `${VAR}`.
- The `kiro` component is opt-in. Select `--components kiro` only on systems that use Kiro CLI.

## Repository Structure

```text
dotfiles/
├── Brewfile                        # Core macOS shell dependencies
├── Brewfile.cmux                   # Optional cmux cask (macOS 14+)
├── install.sh                      # Explicit component installer
├── scripts/                        # Audits and focused integration tests
├── fish/
│   ├── config.fish                 # Interactive fish setup
│   └── wsl-abbreviations.fish      # WSL interactive abbreviations
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
│   │   ├── wsl/                    # WSL-specific Windows notifications
│   │   └── mac/                    # macOS osascript notifications
│   └── settings/
│       ├── wsl.json                # WSL settings template
│       └── mac.json                # macOS settings template
├── codex/
│   ├── AGENTS.md                   # Global instructions for Codex
│   ├── agents/                     # Codex subagent definitions
│   ├── hooks/                      # Codex hook scripts
│   ├── skills/                     # Codex skills
│   ├── config.toml.base            # Default Codex configuration values
│   └── hooks.json.template         # Hook template expanded by install.sh
└── kiro/
    └── steering/
        └── global/                 # Global steering files for Kiro CLI
```
