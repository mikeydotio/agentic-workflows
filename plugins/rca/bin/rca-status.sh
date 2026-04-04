#!/usr/bin/env bash
# rca-status.sh — List RCA investigations with status and summary.
# Usage: rca-status.sh [rca-dir]
# Output: JSON to stdout
set -euo pipefail

RCA_DIR="${1:-.rca}"

# No investigations directory
if [[ ! -d "$RCA_DIR" ]]; then
  jq -n '{"ok":true,"count":0,"investigations":[],"display":"No investigations found."}'
  exit 0
fi

# Gather investigation directories
investigations=()
while IFS= read -r -d '' dir; do
  investigations+=("$dir")
done < <(find "$RCA_DIR" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null | sort -z)

if [[ ${#investigations[@]} -eq 0 ]]; then
  jq -n '{"ok":true,"count":0,"investigations":[],"display":"No investigations found."}'
  exit 0
fi

# Build investigation list
json_items="[]"
display_lines="[rca] Existing investigations:"

for dir in "${investigations[@]}"; do
  slug="$(basename "$dir")"

  # Determine status from artifact presence
  if [[ -f "$dir/REMEDIATION.md" ]]; then
    status="reviewed"
  elif [[ -f "$dir/VERIFICATION.md" ]]; then
    status="complete"
  else
    status="running"
  fi

  # Extract one-line summary from SYMPTOM.md
  summary=""
  if [[ -f "$dir/SYMPTOM.md" ]]; then
    # Try first non-heading, non-empty line
    summary="$(grep -v '^#' "$dir/SYMPTOM.md" | grep -v '^---' | grep -v '^\s*$' | head -1 | cut -c1-120)"
  fi
  [[ -z "$summary" ]] && summary="(no description)"

  # Build AskUserQuestion option
  case "$status" in
    complete)
      label="Review $slug"
      description="$summary"
      ;;
    running)
      label="Check $slug"
      description="Still running — check status"
      ;;
    reviewed)
      label="View $slug"
      description="Investigation complete — $summary"
      ;;
  esac

  # Append to JSON array
  json_items="$(echo "$json_items" | jq \
    --arg slug "$slug" \
    --arg status "$status" \
    --arg summary "$summary" \
    --arg label "$label" \
    --arg desc "$description" \
    '. + [{slug: $slug, status: $status, summary: $summary, option: {label: $label, description: $desc}}]')"

  display_lines="$display_lines
  [$status] $slug — $summary"
done

# Build final output
jq -n \
  --argjson items "$json_items" \
  --arg display "$display_lines" \
  --arg count "${#investigations[@]}" \
  '{ok: true, count: ($count | tonumber), investigations: $items, display: $display}'
