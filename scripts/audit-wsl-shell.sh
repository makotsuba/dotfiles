#!/usr/bin/env sh
# WSL の fish / Starship 移行前に、設定内容を表示せず状態だけを確認する。
set -eu

details_requested=false
case "${1:-}" in
    '')
        ;;
    --details)
        details_requested=true
        ;;
    *)
        printf 'usage: %s [--details]\n' "$0" >&2
        exit 2
        ;;
esac

section() {
    printf '\n== %s ==\n' "$1"
}

command_version() {
    command_name=$1

    if command -v "$command_name" >/dev/null 2>&1; then
        printf '%s: ' "$command_name"
        "$command_name" --version 2>&1 | sed -n '1p'
    else
        printf '%s: not found\n' "$command_name"
    fi
}

command_availability() {
    command_name=$1

    if command -v "$command_name" >/dev/null 2>&1; then
        printf '%s: available (version check skipped to keep this audit read-only)\n' "$command_name"
    else
        printf '%s: not found\n' "$command_name"
    fi
}

has_noncomment_pattern() {
    pattern=$1
    sed '/^[[:space:]]*#/d' "$config_path" | grep -Eq "$pattern"
}

report_fish_identifiers() {
    awk '
        function is_safe_name(name) {
            return name ~ /^[-A-Za-z_][-A-Za-z0-9_]*$/
        }
        function report(kind, name) {
            if (is_safe_name(name)) {
                print kind ": " name
            } else {
                omitted[kind]++
            }
        }
        /^[[:space:]]*#/ { next }
        {
            line = $0
            sub(/^[[:space:]]*/, "", line)
        }
        line ~ /^alias[[:space:]]+/ {
            sub(/^alias[[:space:]]+/, "", line)
            field_count = split(line, fields, /[[:space:]]+/)
            field_index = 1
            if (fields[field_index] == "--save") {
                field_index++
            }
            name = fields[field_index]
            sub(/=.*/, "", name)
            report("alias", name)
            next
        }
        line ~ /^abbr[[:space:]]+/ {
            sub(/^abbr[[:space:]]+/, "", line)
            field_count = split(line, fields, /[[:space:]]+/)
            is_add = 0
            name = ""
            omitted_this_line = 0
            for (field_index = 1; field_index <= field_count; field_index++) {
                token = fields[field_index]
                if (token == "--add" || token == "-a") {
                    is_add = 1
                    continue
                }
                if (!is_add) {
                    continue
                }
                if (token == "--") {
                    field_index++
                    name = fields[field_index]
                    break
                }
                if (token == "--position" || token == "--command" || token == "--regex" || token == "--function") {
                    field_index++
                    continue
                }
                if (token ~ /^--(position|command|regex|function)=/) {
                    continue
                }
                if (token ~ /^-/) {
                    omitted_this_line = 1
                    break
                }
                name = token
                break
            }
            if (name != "") {
                report("abbr", name)
            } else if (is_add && omitted_this_line) {
                omitted["abbr"]++
            } else if (is_add) {
                omitted["abbr"]++
            }
            next
        }
        END {
            for (kind in omitted) {
                print kind " omitted: " omitted[kind]
            }
        }
    ' "$config_path" | LC_ALL=C sort -u
}

report_starship_modules() {
    awk '
        /^[[:space:]]*#/ { next }
        {
            line = $0
            sub(/^[[:space:]]*/, "", line)
        }
        line ~ /^\[[A-Za-z0-9_-]+\][[:space:]]*$/ {
            section = line
            sub(/^\[/, "", section)
            sub(/\]$/, "", section)
            if (section == "direnv" || section == "conda" || section == "nix_shell" || section == "mise" || section == "pixi") {
                found[section] = 1
            }
            next
        }
        line ~ /^\[/ {
            section = ""
            next
        }
        section == "python" && line ~ /(pyenv|asdf|mise)/ {
            found[section] = 1
        }
        section == "ruby" && line ~ /(rbenv|asdf|mise)/ {
            found[section] = 1
        }
        section == "nodejs" && line ~ /(nvm|asdf|mise)/ {
            found[section] = 1
        }
        END {
            count = 0
            for (name in found) {
                print name
                count++
            }
            if (count == 0) {
                print "none detected"
            }
        }
    ' "$config_path" | LC_ALL=C sort -u
}

describe_config() {
    config_path=$1

    if [ -L "$config_path" ]; then
        if [ -e "$config_path" ]; then
            printf '%s: symlink (target exists; target is not printed)\n' "$config_path"
        else
            printf '%s: dangling symlink (target is not printed)\n' "$config_path"
        fi
        return
    fi

    if [ ! -e "$config_path" ]; then
        printf '%s: absent\n' "$config_path"
        return
    fi

    if [ ! -f "$config_path" ]; then
        printf '%s: exists but is not a regular file\n' "$config_path"
        return
    fi

    if [ ! -r "$config_path" ]; then
        printf '%s: regular file but unreadable; inspection skipped\n' "$config_path"
        return
    fi

    printf '%s: readable regular file\n' "$config_path"
    categories=""

    if has_noncomment_pattern 'STARSHIP_CONFIG'; then
        categories="${categories} STARSHIP_CONFIG"
    fi
    if has_noncomment_pattern '^[[:space:]]*(source|\.)[[:space:]]'; then
        categories="${categories} source"
    fi
    if has_noncomment_pattern '^[[:space:]]*(alias|abbr)[[:space:]]'; then
        categories="${categories} alias-or-abbr"
    fi
    if has_noncomment_pattern 'PATH|fish_add_path'; then
        categories="${categories} PATH"
    fi
    if has_noncomment_pattern 'direnv|pyenv|rbenv|nvm|asdf|mise|conda'; then
        categories="${categories} environment-manager"
    fi

    if [ -n "$categories" ]; then
        printf '  detected categories (heuristic):%s\n' "$categories"
    else
        printf '  detected categories (heuristic): none of the migration-sensitive patterns\n'
    fi

    if [ "$config_path" = "$HOME/.config/fish/config.fish" ] && command -v fish >/dev/null 2>&1; then
        if fish -n "$config_path" >/dev/null 2>&1; then
            printf '  fish syntax: valid\n'
        else
            printf '  fish syntax: invalid\n'
        fi
    fi

    if [ "$details_requested" = true ] && [ "$config_path" = "$HOME/.config/fish/config.fish" ]; then
        printf '  identifier names (heuristic):\n'
        report_fish_identifiers | sed 's/^/    /'
    fi

    if [ "$details_requested" = true ] && [ "$config_path" = "$HOME/.config/starship.toml" ]; then
        printf '  environment-manager module sections (heuristic; direct modules plus language-manager settings):\n'
        report_starship_modules | sed 's/^/    /'
    fi
}

if [ -z "${HOME:-}" ]; then
    printf 'error: HOME is not set; cannot locate shell configuration.\n' >&2
    exit 1
fi

if [ -n "${USER:-}" ]; then
    audit_user=$USER
elif command -v id >/dev/null 2>&1; then
    audit_user=$(id -un)
else
    audit_user=unknown
fi

if ! { grep -qi microsoft /proc/version 2>/dev/null ||
       grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null ||
       uname -r 2>/dev/null | grep -qi microsoft; }; then
    printf 'warning: this does not appear to be WSL; continuing with read-only checks.\n' >&2
fi

section 'system'
uname -a
if [ -r /etc/os-release ]; then
    sed -n -E 's/^(PRETTY_NAME|NAME|VERSION_ID)=/\1=/p' /etc/os-release
fi

section 'user and shell'
if command -v getent >/dev/null 2>&1; then
    getent passwd "$audit_user" | awk -F: '{print "user=" $1 " login_shell=" $7}'
else
    printf 'user=%s login_shell=unknown (getent not found)\n' "$audit_user"
fi

section 'shell tools'
command_version fish
command_availability starship

section 'locale'
locale 2>&1 || true

section 'package managers'
for package_manager in apt apt-get brew; do
    if command -v "$package_manager" >/dev/null 2>&1; then
        printf '%s: available\n' "$package_manager"
    else
        printf '%s: not found\n' "$package_manager"
    fi
done

section 'installer prerequisites'
for dependency in bwrap socat npm; do
    if command -v "$dependency" >/dev/null 2>&1; then
        printf '%s: available\n' "$dependency"
    else
        printf '%s: not found\n' "$dependency"
    fi
done

section 'existing shell configuration (values are not printed)'
describe_config "$HOME/.config/fish/config.fish"
describe_config "$HOME/.config/starship.toml"

section 'result'
printf '%s\n' 'This script only reports metadata and pattern categories; it does not print configuration values, symlink targets, or .env files.'
if [ "$details_requested" = true ]; then
    printf '%s\n' 'Details mode statically extracts only simple fish identifier names and Starship section names; complex declarations are omitted.'
fi
