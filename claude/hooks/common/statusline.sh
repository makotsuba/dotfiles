#!/bin/bash
# Two-line statusline
#
# Line 1: Model, folder, branch
# Line 2: Progress bar, context %, session time, 5h usage → reset, 7d usage → reset
#
# Context % uses Claude Code's pre-calculated remaining_percentage,
# which accounts for compaction reserves. 100% = compaction fires.
# API usage limits are read directly from Claude Code's stdin JSON (rate_limits).

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

# Rate limits — provided directly by Claude Code in stdin (no API call needed).
# `resets_at` is a Unix epoch integer. `-` prevents empty TSV fields from
# collapsing under Bash 3.2's whitespace IFS handling.
IFS=$'\t' read -r fh_pct fh_reset sd_pct sd_reset < <(
    echo "$stdin_data" | jq -r '[
        (try (
            if (.rate_limits.five_hour.used_percentage // null) != null then
                (.rate_limits.five_hour.used_percentage | floor | tostring)
            else "-" end
        ) catch "-"),
        (try (.rate_limits.five_hour.resets_at // "-" | tostring) catch "-"),
        (try (
            if (.rate_limits.seven_day.used_percentage // null) != null then
                (.rate_limits.seven_day.used_percentage | floor | tostring)
            else "-" end
        ) catch "-"),
        (try (.rate_limits.seven_day.resets_at // "-" | tostring) catch "-")
    ] | @tsv' 2>/dev/null
)
[[ "$fh_pct" == "-" ]] && fh_pct=""
[[ "$fh_reset" == "-" ]] && fh_reset=""
[[ "$sd_pct" == "-" ]] && sd_pct=""
[[ "$sd_reset" == "-" ]] && sd_reset=""

# Git info
git_branch=$(git -C "$current_dir" -c core.useBuiltinFSMonitor=false branch --show-current 2>/dev/null)
git_root=$(git -C "$current_dir" -c core.useBuiltinFSMonitor=false rev-parse --show-toplevel 2>/dev/null)

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

# Detect GNU vs BSD date
if date --version >/dev/null 2>&1; then
    _DATE_GNU=1
else
    _DATE_GNU=0
fi

# Format Unix epoch → local, compact
#   within 24h → "16:00"
#   further    → "3/20"
_format_reset() {
    local epoch="$1"
    [[ -z "$epoch" ]] && return 1
    [[ "$epoch" =~ ^[0-9]+$ ]] || return 1
    local now diff
    now=$(date +%s)
    diff=$((epoch - now))
    [[ "$diff" -lt 0 ]] && return 1
    if [ "$diff" -le 86400 ]; then
        if [[ "$_DATE_GNU" == "1" ]]; then
            date -d "@$epoch" '+%H:%M' 2>/dev/null
        else
            date -j -r "$epoch" '+%H:%M' 2>/dev/null
        fi
    else
        if [[ "$_DATE_GNU" == "1" ]]; then
            date -d "@$epoch" '+%-m/%-d' 2>/dev/null
        else
            date -j -r "$epoch" '+%m/%d' 2>/dev/null | sed 's|^0*\([0-9][0-9]*\)/0*\([0-9][0-9]*\)|\1/\2|'
        fi
    fi
}

# Usage color: green / yellow / red
_usage_color() {
    local pct="$1"
    [[ "$pct" =~ ^[0-9]+$ ]] || return
    if   [ "$pct" -lt 50 ]; then printf '\033[32m'
    elif [ "$pct" -lt 80 ]; then printf '\033[33m'
    else                          printf '\033[31m'
    fi
}

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
    if [[ -n "$line2" ]]; then
        line2="$line2 $(printf '%b \033[36m⌚ %s\033[0m' "$SEP" "$session_time")"
    else
        line2=$(printf '\033[36m⌚ %s\033[0m' "$session_time")
    fi
fi

# Append each usage window only when Claude Code supplied it.
fh_str=""
sd_str=""
if [[ -n "$fh_pct" ]]; then
    fh_time=$(_format_reset "$fh_reset")
    fh_color=$(_usage_color "$fh_pct")
    fh_str=$(printf '%b5h %s%%\033[0m' "$fh_color" "$fh_pct")
    [[ -n "$fh_time" ]] && fh_str="$fh_str $(printf '\033[37m→ %s\033[0m' "$fh_time")"
fi
if [[ -n "$sd_pct" ]]; then
    sd_time=$(_format_reset "$sd_reset")
    sd_color=$(_usage_color "$sd_pct")
    sd_str=$(printf '%b7d %s%%\033[0m' "$sd_color" "$sd_pct")
    [[ -n "$sd_time" ]] && sd_str="$sd_str $(printf '\033[37m→ %s\033[0m' "$sd_time")"
fi
if [[ -n "$fh_str" ]] && [[ -n "$sd_str" ]]; then
    usage_str=$(printf '%b %b %b' "$fh_str" "$SEP" "$sd_str")
elif [[ -n "$fh_str" ]]; then
    usage_str="$fh_str"
elif [[ -n "$sd_str" ]]; then
    usage_str="$sd_str"
else
    usage_str=""
fi
if [[ -n "$usage_str" ]]; then
    if [[ -n "$line2" ]]; then
        line2="$line2 $(printf '%b %b' "$SEP" "$usage_str")"
    else
        line2="$usage_str"
    fi
fi

if [[ -n "$line2" ]]; then
    printf '%b\n\n%b' "$line1" "$line2"
else
    printf '%b' "$line1"
fi
