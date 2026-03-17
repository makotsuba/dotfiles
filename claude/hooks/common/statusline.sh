#!/bin/bash
# Two-line statusline
#
# Line 1: Model, folder, branch
# Line 2: Progress bar, context %, session time, 5h usage → reset, 7d usage → reset
#
# Context % uses Claude Code's pre-calculated remaining_percentage,
# which accounts for compaction reserves. 100% = compaction fires.
# API usage limits are fetched via OAuth API, cached for 5 minutes, non-blocking.

# Read stdin (Claude Code passes JSON data via stdin)
stdin_data=$(cat)

# Single jq call - extract all values at once
# @tsv with IFS=$'\t' is safe here: all fields always produce non-empty output
# (string fallbacks, numeric 0, or "null" via try/catch), so no field collapsing occurs.
IFS=$'\t' read -r current_dir model_name duration_ms ctx_used < <(
    echo "$stdin_data" | jq -r '[
        .workspace.current_dir // "unknown",
        .model.display_name // "Unknown",
        (.cost.total_duration_ms // 0),
        (try (
            if (.context_window.remaining_percentage // null) != null then
                100 - (.context_window.remaining_percentage | floor)
            elif (.context_window.context_window_size // 0) > 0 then
                (((.context_window.current_usage.input_tokens // 0) +
                  (.context_window.current_usage.cache_creation_input_tokens // 0) +
                  (.context_window.current_usage.cache_read_input_tokens // 0)) * 100 /
                 .context_window.context_window_size) | floor
            else "null" end
        ) catch "null")
    ] | @tsv'
)

# Bash-level fallback: if jq crashed entirely
if [[ -z "$current_dir" ]] && [[ -z "$model_name" ]]; then
    current_dir=$(echo "$stdin_data" | jq -r '.workspace.current_dir // .cwd // "unknown"' 2>/dev/null)
    model_name=$(echo "$stdin_data" | jq -r '.model.display_name // "Unknown"' 2>/dev/null)
    duration_ms=$(echo "$stdin_data" | jq -r '(.cost.total_duration_ms // 0)' 2>/dev/null)
    ctx_used=""
    : "${current_dir:=unknown}"
    : "${model_name:=Unknown}"
    : "${duration_ms:=0}"
fi

# Git info
if cd "$current_dir" 2>/dev/null; then
    git_branch=$(git -c core.useBuiltinFSMonitor=false branch --show-current 2>/dev/null)
    git_root=$(git -c core.useBuiltinFSMonitor=false rev-parse --show-toplevel 2>/dev/null)
fi

# Build repo path display (folder name only for brevity)
if [[ -n "$git_root" ]] && [[ "$current_dir" == "$git_root" ]]; then
    folder_name=$(basename "$git_root")
else
    folder_name=$(basename "$current_dir")
fi

# Generate visual progress bar for context usage
progress_bar=""
bar_width=12

if [[ -n "$ctx_used" ]] && [[ "$ctx_used" != "null" ]]; then
    # Clamp to 100 to prevent bar overflow
    [ "$ctx_used" -gt 100 ] && ctx_used=100

    filled=$((ctx_used * bar_width / 100))
    empty=$((bar_width - filled))

    if [ "$ctx_used" -lt 50 ]; then
        bar_color='\033[32m'
    elif [ "$ctx_used" -lt 80 ]; then
        bar_color='\033[33m'
    else
        bar_color='\033[31m'
    fi

    progress_bar="${bar_color}"
    for ((i=0; i<filled; i++)); do progress_bar="${progress_bar}█"; done
    progress_bar="${progress_bar}\033[2m"
    for ((i=0; i<empty; i++)); do progress_bar="${progress_bar}⣿"; done
    progress_bar="${progress_bar}\033[0m"

    ctx_pct="${ctx_used}%"
else
    ctx_pct=""
fi

# === API Usage Limits (5h / 7d) — cached, non-blocking ===
CACHE_FILE="${TMPDIR:-/tmp}/claude_statusline_usage_${UID}.json"
CACHE_TTL=300  # 5 minutes

# Detect GNU vs BSD date once at startup
if date --version >/dev/null 2>&1; then
    _DATE_GNU=1
else
    _DATE_GNU=0
fi

# Strip fractional seconds and timezone from ISO 8601 for BSD date parsing.
# Handles: +HH:MM, -HH:MM, Z suffixes.
_iso_strip_tz() {
    echo "$1" | sed -E 's/(\.[0-9]*)?(Z|[-+][0-9]{2}:[0-9]{2})?$//'
}

_iso_to_epoch() {
    local iso="$1"
    if [[ "$_DATE_GNU" == "1" ]]; then
        date -d "$iso" +%s 2>/dev/null
    else
        # TZ=UTC ensures stripped datetime is interpreted as UTC, not local time
        TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%S" "$(_iso_strip_tz "$iso")" +%s 2>/dev/null
    fi
}

_fetch_usage_bg() {
    local lock_file="${CACHE_FILE}.lock"
    # mkdir is atomic — only one process succeeds
    mkdir "$lock_file" 2>/dev/null || return
    trap 'rm -rf "$lock_file"' EXIT
    local token
    token=$(jq -r '.claudeAiOauth.accessToken' ~/.claude/.credentials.json 2>/dev/null)
    # macOS Keychain fallback (credentials.json not created on Mac)
    if [[ "$OSTYPE" == darwin* ]] && { [[ -z "$token" ]] || [[ "$token" == "null" ]]; }; then
        token=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null \
            | jq -r '.claudeAiOauth.accessToken' 2>/dev/null)
    fi
    if [[ -n "$token" ]] && [[ "$token" != "null" ]]; then
        # Sanity check: reject if token contains newlines or curl config metacharacters
        [[ "$token" =~ ^[A-Za-z0-9._/+=~-]+$ ]] || return
        local result
        # Pass token via stdin (--config -) to avoid exposure in process list (ps aux)
        result=$(printf 'header = "Authorization: Bearer %s"\nheader = "anthropic-beta: oauth-2025-04-20"\n' "$token" \
            | curl -s --max-time 5 --config - "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)
        if echo "$result" | jq -e '.five_hour' >/dev/null 2>&1; then
            # umask 077: file is created 600 from the start, no world-readable window
            (umask 077; echo "{\"ts\":$(date +%s),\"data\":$result}" > "$CACHE_FILE")
        fi
    fi
    rm -rf "$lock_file"
}

# Format ISO reset time → local, compact (cross-platform: Linux & macOS)
#   within 24h → "16:00"
#   further    → "3/20"
_format_reset() {
    local iso="$1"
    [[ -z "$iso" ]] && return
    local now reset_epoch diff
    now=$(date +%s)
    reset_epoch=$(_iso_to_epoch "$iso") || return
    [[ -z "$reset_epoch" ]] && return
    diff=$((reset_epoch - now))
    [[ "$diff" -lt 0 ]] && return  # already elapsed — don't display stale time
    if [ "$diff" -le 86400 ]; then
        # Within 24 hours: time only — display via epoch (auto local time on both platforms)
        if [[ "$_DATE_GNU" == "1" ]]; then
            date -d "@$reset_epoch" '+%H:%M' 2>/dev/null
        else
            date -j -r "$reset_epoch" '+%H:%M' 2>/dev/null
        fi
    else
        # Further away: date only
        if [[ "$_DATE_GNU" == "1" ]]; then
            date -d "@$reset_epoch" '+%-m/%-d' 2>/dev/null
        else
            date -j -r "$reset_epoch" '+%-m/%-d' 2>/dev/null
        fi
    fi
}

# Usage color: green / yellow / red
_usage_color() {
    local pct="$1"
    if   [ "$pct" -lt 50 ]; then printf '\033[32m'
    elif [ "$pct" -lt 80 ]; then printf '\033[33m'
    else                          printf '\033[31m'
    fi
}

usage_json=""
if [[ -f "$CACHE_FILE" ]]; then
    cached_ts=$(jq -r '.ts // 0' "$CACHE_FILE" 2>/dev/null)
    now=$(date +%s)
    age=$((now - ${cached_ts:-0}))
    usage_json=$(jq -r '.data' "$CACHE_FILE" 2>/dev/null)
    if [ "$age" -ge "$CACHE_TTL" ] && [[ ! -d "${CACHE_FILE}.lock" ]]; then
        (_fetch_usage_bg) &>/dev/null &
        disown
    fi
else
    (_fetch_usage_bg) &>/dev/null &
    disown
fi

# Separator
SEP='\033[2m│\033[0m'

# Short model name
short_model=$(echo "$model_name" | sed -E 's/Claude [0-9.]+ //; s/^Claude //')

# LINE 1: [Model] 📁 folder │ 🌿 branch
line1=$(printf '\033[37m[%s]\033[0m' "$short_model")
line1="$line1 $(printf '\033[94m📁 %s\033[0m' "$folder_name")"
if [[ -n "$git_branch" ]]; then
    line1="$line1 $(printf '%b \033[96m🌿 %s\033[0m' "$SEP" "$git_branch")"
fi

# Session time (human-readable)
if [ "${duration_ms:-0}" -gt 0 ] 2>/dev/null; then
    total_sec=$((duration_ms / 1000))
    hours=$((total_sec / 3600))
    minutes=$(((total_sec % 3600) / 60))
    seconds=$((total_sec % 60))
    if [ "$hours" -gt 0 ]; then
        session_time="${hours}h ${minutes}m"
    elif [ "$minutes" -gt 0 ]; then
        session_time="${minutes}m"
    else
        session_time="${seconds}s"
    fi
else
    session_time=""
fi

# LINE 2: bar % │ ⌚ time │ 5h XX% → HH:MM │ 7d XX% → M/D
line2=""
if [[ -n "$progress_bar" ]]; then
    line2=$(printf '%b' "$progress_bar")
fi
if [[ -n "$ctx_pct" ]]; then
    if [[ -n "$line2" ]]; then
        line2="$line2 $(printf '\033[37m%s\033[0m' "$ctx_pct")"
    else
        line2=$(printf '\033[37m%s\033[0m' "$ctx_pct")
    fi
fi
if [[ -n "$session_time" ]]; then
    line2="$line2 $(printf '%b \033[36m⌚ %s\033[0m' "$SEP" "$session_time")"
fi

# Append 5h / 7d usage if available
if [[ -n "$usage_json" ]] && [[ "$usage_json" != "null" ]]; then
    # Use \u0001 (SOH) as delimiter — tab is IFS whitespace and collapses consecutive
    # empty fields, causing field misalignment when fh_reset or sd_reset is absent.
    IFS=$'\001' read -r fh_pct fh_reset sd_pct sd_reset < <(
        echo "$usage_json" | jq -r '[
            (.five_hour.utilization  // 0 | floor | tostring),
            (.five_hour.resets_at   // ""),
            (.seven_day.utilization  // 0 | floor | tostring),
            (.seven_day.resets_at   // "")
        ] | join("\u0001")'
    )

    fh_time=$(_format_reset "$fh_reset")
    sd_time=$(_format_reset "$sd_reset")
    fh_color=$(_usage_color "$fh_pct")
    sd_color=$(_usage_color "$sd_pct")

    fh_str=$(printf "${fh_color}5h %s%%\033[0m" "$fh_pct")
    [[ -n "$fh_time" ]] && fh_str="$fh_str $(printf '\033[37m→ %s\033[0m' "$fh_time")"
    sd_str=$(printf "${sd_color}7d %s%%\033[0m" "$sd_pct")
    [[ -n "$sd_time" ]] && sd_str="$sd_str $(printf '\033[37m→ %s\033[0m' "$sd_time")"

    if [[ -n "$line2" ]]; then
        line2="$line2 $(printf '%b %b %b %b' "$SEP" "$fh_str" "$SEP" "$sd_str")"
    else
        line2=$(printf '%b %b %b' "$fh_str" "$SEP" "$sd_str")
    fi
fi

if [[ -n "$line2" ]]; then
    printf '%b\n\n%b' "$line1" "$line2"
else
    printf '%b' "$line1"
fi
