#!/bin/bash
# Claude Code status line
# Layout: <model> | <5h gauge> / <7d gauge> / <ctx gauge> | <git branch>

input=$(cat)

model=$(echo "$input" | jq -r '.model.display_name // "Claude"')
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // "."')

# --- colors (raw ANSI escapes, dimmed to fit the terminal theme) ---
RESET=$'\033[0m'
DIM=$'\033[2m'
BOLD=$'\033[1m'
CYAN=$'\033[36m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
RED=$'\033[31m'
MAGENTA=$'\033[35m'
GRAY=$'\033[90m'

# --- git branch (skip optional locks so we never block on a git lock) ---
branch=""
if git -C "$cwd" --no-optional-locks rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null)
  if [ -z "$branch" ]; then
    branch=$(git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
  fi
fi

# --- gauge builder: $1 = label, $2 = percentage (0-100, may be empty) ---
gauge() {
  local label="$1" pct="$2" width=8

  if [ -z "$pct" ] || [ "$pct" = "null" ]; then
    printf '%s%s --%s' "$GRAY" "$label" "$RESET"
    return
  fi

  local pct_int=${pct%.*}
  [ -z "$pct_int" ] && pct_int=0
  [ "$pct_int" -gt 100 ] && pct_int=100
  [ "$pct_int" -lt 0 ] && pct_int=0

  local filled=$(( pct_int * width / 100 ))
  local empty=$(( width - filled ))

  local color="$GREEN"
  if [ "$pct_int" -ge 80 ]; then
    color="$RED"
  elif [ "$pct_int" -ge 50 ]; then
    color="$YELLOW"
  fi

  local bar="" i=0
  while [ $i -lt $filled ]; do bar="${bar}█"; i=$((i+1)); done
  i=0
  while [ $i -lt $empty ]; do bar="${bar}░"; i=$((i+1)); done

  printf '%s%s%s %s%s%s %s%d%%%s' "$DIM" "$label" "$RESET" "$color" "$bar" "$RESET" "$DIM" "$pct_int" "$RESET"
}

five_h=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
seven_d=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
ctx=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

gauge_5h=$(gauge "5h" "$five_h")
gauge_7d=$(gauge "7d" "$seven_d")
gauge_ctx=$(gauge "ctx" "$ctx")

line="${BOLD}${CYAN}${model}${RESET} ${DIM}|${RESET} ${gauge_5h} ${DIM}/${RESET} ${gauge_7d} ${DIM}/${RESET} ${gauge_ctx}"

if [ -n "$branch" ]; then
  line="${line} ${DIM}|${RESET}${MAGENTA} ${branch}${RESET}"
fi

printf '%s\n' "$line"
