#!/bin/bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATUSLINE="$DOTFILES_DIR/claude/hooks/common/statusline.sh"
now=$(date +%s)

strip_ansi() {
    sed $'s/\033\\[[0-9;]*m//g'
}

run_statusline() {
    printf '%s' "$1" | "$STATUSLINE" | strip_ansi
}

both=$(run_statusline "{\"workspace\":{\"current_dir\":\"$DOTFILES_DIR\"},\"model\":{\"display_name\":\"Claude Opus 4\"},\"cost\":{\"total_duration_ms\":65000},\"context_window\":{\"remaining_percentage\":75},\"rate_limits\":{\"five_hour\":{\"used_percentage\":24.9,\"resets_at\":$((now + 3600))},\"seven_day\":{\"used_percentage\":41.2,\"resets_at\":$((now + 172800))}}}")
grep -Fq '5h 24%' <<<"$both"
grep -Fq '7d 41%' <<<"$both"

five_hour_only=$(run_statusline "{\"workspace\":{\"current_dir\":\"$DOTFILES_DIR\"},\"model\":{\"display_name\":\"Claude Sonnet 4\"},\"rate_limits\":{\"five_hour\":{\"used_percentage\":55,\"resets_at\":$((now + 3600))}}}")
grep -Fq '5h 55%' <<<"$five_hour_only"
if grep -Fq '7d ' <<<"$five_hour_only"; then
    echo 'Assertion failed: absent seven-day limit was displayed' >&2
    exit 1
fi

absent=$(run_statusline "{\"workspace\":{\"current_dir\":\"$DOTFILES_DIR\"},\"model\":{\"display_name\":\"Claude Haiku\"}}")
if grep -Eq '(^| )([57]h|7d) ' <<<"$absent"; then
    echo 'Assertion failed: absent rate limits were displayed' >&2
    exit 1
fi

expired=$(run_statusline "{\"workspace\":{\"current_dir\":\"$DOTFILES_DIR\"},\"model\":{\"display_name\":\"Claude Opus 4\"},\"rate_limits\":{\"five_hour\":{\"used_percentage\":80,\"resets_at\":$((now - 1))}}}")
grep -Fq '5h 80%' <<<"$expired"
if grep -Fq '→' <<<"$expired"; then
    echo 'Assertion failed: expired reset time was displayed' >&2
    exit 1
fi

echo 'statusline tests passed'
