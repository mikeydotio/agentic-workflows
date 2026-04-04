#!/usr/bin/env bats
# Tests for forge-status.sh

SCRIPT="$BATS_TEST_DIRNAME/../plugins/forge/bin/forge-status.sh"

setup() {
  TEST_DIR="$(mktemp -d)"
  export TEST_DIR
  FORGE_DIR="$TEST_DIR/.forge"
  mkdir -p "$FORGE_DIR"
}

teardown() {
  if [[ -n "${TEST_DIR:-}" && -d "$TEST_DIR" ]]; then
    rm -rf "$TEST_DIR"
  fi
}

# --- Output structure ---

@test "status: output is valid JSON" {
  run bash "$SCRIPT" "$FORGE_DIR"
  echo "$output" >&2
  echo "$output" | jq . >/dev/null
}

@test "status: ok is true" {
  run bash "$SCRIPT" "$FORGE_DIR"
  local ok
  ok="$(echo "$output" | jq -r '.ok')"
  [ "$ok" = "true" ]
}

@test "status: has display field" {
  run bash "$SCRIPT" "$FORGE_DIR"
  echo "$output" | jq -e '.display' >/dev/null
}

@test "status: has state field" {
  run bash "$SCRIPT" "$FORGE_DIR"
  echo "$output" | jq -e '.state' >/dev/null
}

@test "status: has artifacts field" {
  run bash "$SCRIPT" "$FORGE_DIR"
  echo "$output" | jq -e '.artifacts' >/dev/null
}

@test "status: has config field" {
  run bash "$SCRIPT" "$FORGE_DIR"
  echo "$output" | jq -e '.config' >/dev/null
}

# --- State detection ---

@test "status: detects interrogate state when no artifacts" {
  run bash "$SCRIPT" "$FORGE_DIR"
  local state
  state="$(echo "$output" | jq -r '.state')"
  [ "$state" = "interrogate" ]
}

@test "status: detects research state when IDEA.md exists" {
  echo "idea" > "$FORGE_DIR/IDEA.md"
  run bash "$SCRIPT" "$FORGE_DIR"
  local state
  state="$(echo "$output" | jq -r '.state')"
  [ "$state" = "research" ]
}

@test "status: detects design state" {
  echo "idea" > "$FORGE_DIR/IDEA.md"
  mkdir -p "$FORGE_DIR/research"
  echo "summary" > "$FORGE_DIR/research/SUMMARY.md"
  run bash "$SCRIPT" "$FORGE_DIR"
  local state
  state="$(echo "$output" | jq -r '.state')"
  [ "$state" = "design" ]
}

@test "status: detects plan state" {
  echo "idea" > "$FORGE_DIR/IDEA.md"
  mkdir -p "$FORGE_DIR/research"
  echo "summary" > "$FORGE_DIR/research/SUMMARY.md"
  echo "design" > "$FORGE_DIR/DESIGN.md"
  run bash "$SCRIPT" "$FORGE_DIR"
  local state
  state="$(echo "$output" | jq -r '.state')"
  [ "$state" = "plan" ]
}

# --- Display format ---

@test "status: display contains header" {
  run bash "$SCRIPT" "$FORGE_DIR"
  local display
  display="$(echo "$output" | jq -r '.display')"
  [[ "$display" == *"Forge Pipeline Status"* ]]
}

@test "status: display contains current step" {
  run bash "$SCRIPT" "$FORGE_DIR"
  local display
  display="$(echo "$output" | jq -r '.display')"
  [[ "$display" == *"Current step"* ]]
}

@test "status: display contains mode" {
  run bash "$SCRIPT" "$FORGE_DIR"
  local display
  display="$(echo "$output" | jq -r '.display')"
  [[ "$display" == *"Mode"* ]]
}

@test "status: display contains artifacts section" {
  run bash "$SCRIPT" "$FORGE_DIR"
  local display
  display="$(echo "$output" | jq -r '.display')"
  [[ "$display" == *"Artifacts"* ]]
}

@test "status: display shows IDEA.md as exists when present" {
  echo "idea" > "$FORGE_DIR/IDEA.md"
  run bash "$SCRIPT" "$FORGE_DIR"
  local display
  display="$(echo "$output" | jq -r '.display')"
  [[ "$display" == *"IDEA.md: exists"* ]]
}

@test "status: display shows IDEA.md as missing when absent" {
  run bash "$SCRIPT" "$FORGE_DIR"
  local display
  display="$(echo "$output" | jq -r '.display')"
  [[ "$display" == *"IDEA.md: missing"* ]]
}

# --- Config reading ---

@test "status: reads yolo mode from config" {
  echo '{"yolo": true}' > "$FORGE_DIR/config.json"
  run bash "$SCRIPT" "$FORGE_DIR"
  local mode
  mode="$(echo "$output" | jq -r '.config.yolo')"
  [ "$mode" = "true" ]
}

@test "status: defaults to normal mode without config" {
  run bash "$SCRIPT" "$FORGE_DIR"
  local display
  display="$(echo "$output" | jq -r '.display')"
  [[ "$display" == *"normal"* ]]
}

@test "status: display shows yolo mode" {
  echo '{"yolo": true}' > "$FORGE_DIR/config.json"
  run bash "$SCRIPT" "$FORGE_DIR"
  local display
  display="$(echo "$output" | jq -r '.display')"
  [[ "$display" == *"yolo"* ]]
}

# --- Fix cycles ---

@test "status: counts zero fix cycles" {
  run bash "$SCRIPT" "$FORGE_DIR"
  local display
  display="$(echo "$output" | jq -r '.display')"
  [[ "$display" == *"Fix Cycles"* ]]
}

@test "status: counts existing fix cycles" {
  mkdir -p "$FORGE_DIR/fix-cycles/cycle-0"
  mkdir -p "$FORGE_DIR/fix-cycles/cycle-1"
  run bash "$SCRIPT" "$FORGE_DIR"
  local fix
  fix="$(echo "$output" | jq -r '.fix_cycles')"
  [ "$fix" = "2" ]
}

# --- Handoffs ---

@test "status: lists recent handoffs" {
  mkdir -p "$FORGE_DIR/handoffs"
  echo "h1" > "$FORGE_DIR/handoffs/handoff-interrogate.md"
  echo "h2" > "$FORGE_DIR/handoffs/handoff-research.md"
  run bash "$SCRIPT" "$FORGE_DIR"
  local display
  display="$(echo "$output" | jq -r '.display')"
  [[ "$display" == *"Recent Handoffs"* ]]
  [[ "$display" == *"handoff-interrogate.md"* ]]
}

@test "status: shows no handoffs message when none exist" {
  run bash "$SCRIPT" "$FORGE_DIR"
  local display
  display="$(echo "$output" | jq -r '.display')"
  [[ "$display" == *"Recent Handoffs"* ]]
}

# --- Missing forge dir ---

@test "status: handles missing forge dir gracefully" {
  run bash "$SCRIPT" "$TEST_DIR/nonexistent"
  local ok
  ok="$(echo "$output" | jq -r '.ok')"
  [ "$ok" = "true" ]
  local state
  state="$(echo "$output" | jq -r '.state')"
  [ "$state" = "interrogate" ]
}

# --- Execution progress ---

@test "status: includes execution progress when state.json exists" {
  echo "idea" > "$FORGE_DIR/IDEA.md"
  mkdir -p "$FORGE_DIR/research"
  echo "summary" > "$FORGE_DIR/research/SUMMARY.md"
  echo "design" > "$FORGE_DIR/DESIGN.md"
  echo "plan" > "$FORGE_DIR/PLAN.md"
  echo '{"stories": {}}' > "$FORGE_DIR/plan-mapping.json"
  echo '{"status": "running", "sessions_completed": 2, "stories_attempted": 5, "stories_this_session": 3}' > "$FORGE_DIR/state.json"
  run bash "$SCRIPT" "$FORGE_DIR"
  local display
  display="$(echo "$output" | jq -r '.display')"
  [[ "$display" == *"Execution Progress"* ]]
}
