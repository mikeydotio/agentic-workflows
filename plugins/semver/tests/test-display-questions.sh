#!/usr/bin/env bash
# Tests for display and questions keys in semver-cli JSON output.
# Covers: build_display helper, display in current/validate/bump gather/execute/
#         first-version/tracking/auto-bump/repair, questions in bump gather/
#         tracking stop-gather/auto-bump/repair diagnose.

# --- Helper: create a semver-tracked repo ---

create_semver_repo() {
    local dir
    dir=$(mktemp -d "/tmp/semver-test-XXXXXX")
    cd "$dir"
    git init -q
    git branch -M main
    git config user.name "Test"
    git config user.email "test@test.com"

    # Initial commit
    echo "init" > README.md
    git add README.md
    git commit -q -m "chore: initial commit"

    # Initialize semver config
    mkdir -p .semver
    cat > .semver/config.yaml << 'YAML'
tracking: true
auto_bump: false
auto_bump_confirm: true
version_prefix: "v"
git_tagging: true
changelog_format: "grouped"
target_branch: "main"
YAML

    echo "v1.0.0" > VERSION
    cat > CHANGELOG.md << 'CL'
# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [v1.0.0] - 2026-01-01

- Initial version tracking

_[manual]_
CL
    git add -A
    git commit -q -m "chore: initialize semver tracking"
    git tag v1.0.0

    echo "$dir"
}


# ═══════════════════════════════════════════════════════════════════════════
# A. cmd_current — display key
# ═══════════════════════════════════════════════════════════════════════════

test_current_has_display() {
    local repo
    repo=$(create_semver_repo)
    trap "cleanup_test_repo '$repo'" RETURN

    local out
    out=$(cd "$repo" && "$CLI" current)

    local display
    display=$(echo "$out" | jq -r '.display')
    assert_ne "null" "$display" "display should be present" &&
    # Should start with [semver]
    [[ "$display" == *"[semver]"* ]] || { echo "    FAIL: display should contain [semver] prefix"; return 1; } &&
    # Should contain version string
    [[ "$display" == *"v1.0.0"* ]] || { echo "    FAIL: display should contain version"; return 1; } &&
    # Should contain Auto-bump
    [[ "$display" == *"Auto-bump:"* ]] || { echo "    FAIL: display should contain Auto-bump info"; return 1; }
}

test_current_no_version_display() {
    local repo
    repo=$(create_semver_repo)
    trap "cleanup_test_repo '$repo'" RETURN

    rm "$repo/VERSION"
    git -C "$repo" add -A
    git -C "$repo" commit -q -m "chore: remove VERSION"

    local out
    out=$(cd "$repo" && "$CLI" current)

    local display
    display=$(echo "$out" | jq -r '.display')
    [[ "$display" == *"No version set"* ]] || { echo "    FAIL: display should say no version set"; return 1; }
}


# ═══════════════════════════════════════════════════════════════════════════
# B. cmd_validate — display key
# ═══════════════════════════════════════════════════════════════════════════

test_validate_has_display() {
    local repo
    repo=$(create_semver_repo)
    trap "cleanup_test_repo '$repo'" RETURN

    local out
    out=$(cd "$repo" && "$CLI" validate)

    local display
    display=$(echo "$out" | jq -r '.display')
    assert_ne "null" "$display" "display should be present" &&
    [[ "$display" == *"Validation results"* ]] || { echo "    FAIL: display should contain Validation results header"; return 1; } &&
    [[ "$display" == *"All checks passed"* ]] || { echo "    FAIL: display should say all passed"; return 1; }
}

test_validate_failure_display() {
    local repo
    repo=$(create_semver_repo)
    trap "cleanup_test_repo '$repo'" RETURN

    git -C "$repo" tag -d v1.0.0

    local out
    out=$(cd "$repo" && "$CLI" validate)

    local display
    display=$(echo "$out" | jq -r '.display')
    [[ "$display" == *"failure"* ]] || { echo "    FAIL: display should mention failures"; return 1; } &&
    [[ "$display" == *"/semver repair"* ]] || { echo "    FAIL: display should suggest repair"; return 1; }
}


# ═══════════════════════════════════════════════════════════════════════════
# C. cmd_bump_gather — display and questions keys
# ═══════════════════════════════════════════════════════════════════════════

test_bump_gather_has_display() {
    local repo
    repo=$(create_semver_repo)
    trap "cleanup_test_repo '$repo'" RETURN

    echo "feature" > "$repo/feature.txt"
    git -C "$repo" add -A
    git -C "$repo" commit -q -m "feat: add new feature"

    local out
    out=$(cd "$repo" && "$CLI" bump gather minor)

    local display
    display=$(echo "$out" | jq -r '.display')
    assert_ne "null" "$display" "display should be present" &&
    [[ "$display" == *"Preparing"* ]] || { echo "    FAIL: display should contain Preparing"; return 1; } &&
    [[ "$display" == *"v1.0.0"* ]] || { echo "    FAIL: display should contain old version"; return 1; } &&
    [[ "$display" == *"v1.1.0"* ]] || { echo "    FAIL: display should contain new version"; return 1; }
}

test_bump_gather_has_questions_array() {
    local repo
    repo=$(create_semver_repo)
    trap "cleanup_test_repo '$repo'" RETURN

    # Create dirty tree to trigger a question
    echo "feature" > "$repo/feature.txt"
    git -C "$repo" add -A
    git -C "$repo" commit -q -m "feat: add feature"
    echo "uncommitted" > "$repo/dirty.txt"

    local out
    out=$(cd "$repo" && "$CLI" bump gather minor)

    # questions array should exist
    local q_len
    q_len=$(echo "$out" | jq '.questions | length')
    assert_ne "null" "$q_len" "questions should be an array" &&
    [ "$q_len" -gt 0 ] || { echo "    FAIL: questions should have entries for dirty tree"; return 1; }

    # Dirty tree question should have correct structure
    local dirty_q
    dirty_q=$(echo "$out" | jq '.questions[] | select(.id == "dirty_tree")')
    assert_ne "" "$dirty_q" "should have dirty_tree question" &&

    local q_header
    q_header=$(echo "$dirty_q" | jq -r '.header')
    assert_eq "Dirty tree" "$q_header" "dirty_tree question header" &&

    local q_opts
    q_opts=$(echo "$dirty_q" | jq '.options | length')
    assert_eq "3" "$q_opts" "dirty_tree should have 3 options"
}

test_bump_gather_wrong_branch_question() {
    local repo
    repo=$(create_semver_repo)
    trap "cleanup_test_repo '$repo'" RETURN

    git -C "$repo" checkout -q -b feature-branch
    echo "feature" > "$repo/feature.txt"
    git -C "$repo" add -A
    git -C "$repo" commit -q -m "feat: add feature"

    local out
    out=$(cd "$repo" && "$CLI" bump gather minor)

    local branch_q
    branch_q=$(echo "$out" | jq '.questions[] | select(.id == "wrong_branch")')
    assert_ne "" "$branch_q" "should have wrong_branch question" &&

    local q_text
    q_text=$(echo "$branch_q" | jq -r '.question')
    [[ "$q_text" == *"feature-branch"* ]] || { echo "    FAIL: question should mention current branch"; return 1; }
}

test_bump_gather_first_version_question() {
    local repo
    repo=$(create_semver_repo)
    trap "cleanup_test_repo '$repo'" RETURN

    rm "$repo/VERSION"
    git -C "$repo" add -A
    git -C "$repo" commit -q -m "chore: remove VERSION"

    local out
    out=$(cd "$repo" && "$CLI" bump gather minor)

    local fv_q
    fv_q=$(echo "$out" | jq '.questions[] | select(.id == "first_version")')
    assert_ne "" "$fv_q" "should have first_version question" &&

    local q_opts
    q_opts=$(echo "$fv_q" | jq '.options | length')
    assert_eq "3" "$q_opts" "first_version should have 3 options"

    local display
    display=$(echo "$out" | jq -r '.display')
    [[ "$display" == *"No version set"* ]] || { echo "    FAIL: display should say no version set for first version"; return 1; }
}

test_bump_gather_questions_preserved_alongside_questions_needed() {
    local repo
    repo=$(create_semver_repo)
    trap "cleanup_test_repo '$repo'" RETURN

    echo "feature" > "$repo/feature.txt"
    git -C "$repo" add -A
    git -C "$repo" commit -q -m "feat: add feature"
    echo "uncommitted" > "$repo/dirty.txt"

    local out
    out=$(cd "$repo" && "$CLI" bump gather minor)

    # Both old and new keys should exist
    local qn
    qn=$(echo "$out" | jq '.questions_needed | length')
    [ "$qn" -gt 0 ] || { echo "    FAIL: questions_needed should still exist"; return 1; }

    local qs
    qs=$(echo "$out" | jq '.questions | length')
    [ "$qs" -gt 0 ] || { echo "    FAIL: questions should also exist"; return 1; }
}


# ═══════════════════════════════════════════════════════════════════════════
# D. cmd_bump_execute — display key
# ═══════════════════════════════════════════════════════════════════════════

test_bump_execute_has_display() {
    local repo
    repo=$(create_semver_repo)
    trap "cleanup_test_repo '$repo'" RETURN

    echo "feature" > "$repo/feature.txt"
    git -C "$repo" add -A
    git -C "$repo" commit -q -m "feat: add new feature"

    local out
    out=$(cd "$repo" && "$CLI" bump execute minor)

    local display
    display=$(echo "$out" | jq -r '.display')
    assert_ne "null" "$display" "display should be present" &&
    [[ "$display" == *"Bumped"* ]] || { echo "    FAIL: display should contain Bumped"; return 1; } &&
    [[ "$display" == *"v1.0.0"* ]] || { echo "    FAIL: display should contain old version"; return 1; } &&
    [[ "$display" == *"v1.1.0"* ]] || { echo "    FAIL: display should contain new version"; return 1; } &&
    [[ "$display" == *"Tag:"* ]] || { echo "    FAIL: display should mention tag"; return 1; }
}


# ═══════════════════════════════════════════════════════════════════════════
# E. cmd_bump_first_version — display key
# ═══════════════════════════════════════════════════════════════════════════

test_bump_first_version_has_display() {
    local repo
    repo=$(create_semver_repo)
    trap "cleanup_test_repo '$repo'" RETURN

    rm "$repo/VERSION" "$repo/CHANGELOG.md"
    git -C "$repo" add -A
    git -C "$repo" commit -q -m "chore: remove version files"

    local out
    out=$(cd "$repo" && "$CLI" bump first-version 0.1.0)

    local display
    display=$(echo "$out" | jq -r '.display')
    assert_ne "null" "$display" "display should be present" &&
    [[ "$display" == *"Initialized"* ]] || { echo "    FAIL: display should say initialized"; return 1; } &&
    [[ "$display" == *"v0.1.0"* ]] || { echo "    FAIL: display should contain version"; return 1; } &&
    [[ "$display" == *"CHANGELOG"* ]] || { echo "    FAIL: display should mention CHANGELOG"; return 1; }
}


# ═══════════════════════════════════════════════════════════════════════════
# F. cmd_tracking_stop_gather — display and questions
# ═══════════════════════════════════════════════════════════════════════════

test_tracking_stop_gather_has_display_and_questions() {
    local repo
    repo=$(create_semver_repo)
    trap "cleanup_test_repo '$repo'" RETURN

    local out
    out=$(cd "$repo" && "$CLI" tracking stop-gather)

    local display
    display=$(echo "$out" | jq -r '.display')
    assert_ne "null" "$display" "display should be present" &&
    [[ "$display" == *"stop tracking"* ]] || { echo "    FAIL: display should mention stop tracking"; return 1; }

    # Questions array
    local q_len
    q_len=$(echo "$out" | jq '.questions | length')
    [ "$q_len" -gt 0 ] || { echo "    FAIL: questions should have entries"; return 1; }

    # Archive items question
    local archive_q
    archive_q=$(echo "$out" | jq '.questions[] | select(.id == "archive_items")')
    assert_ne "" "$archive_q" "should have archive_items question" &&

    local multi
    multi=$(echo "$archive_q" | jq -r '.multi_select')
    assert_eq "true" "$multi" "archive_items should be multi_select"
}

test_tracking_stop_gather_tag_deletion_question() {
    local repo
    repo=$(create_semver_repo)
    trap "cleanup_test_repo '$repo'" RETURN

    local out
    out=$(cd "$repo" && "$CLI" tracking stop-gather)

    # Should have tag_deletion question since there are tags
    local tag_q
    tag_q=$(echo "$out" | jq '.questions[] | select(.id == "tag_deletion")')
    assert_ne "" "$tag_q" "should have tag_deletion question" &&

    local q_opts
    q_opts=$(echo "$tag_q" | jq '.options | length')
    assert_eq "3" "$q_opts" "tag_deletion should have 3 options"
}


# ═══════════════════════════════════════════════════════════════════════════
# G. cmd_tracking_stop_execute — display key
# ═══════════════════════════════════════════════════════════════════════════

test_tracking_stop_execute_has_display() {
    local repo
    repo=$(create_semver_repo)
    trap "cleanup_test_repo '$repo'" RETURN

    local out
    out=$(cd "$repo" && "$CLI" tracking stop-execute --archive version,changelog)

    local display
    display=$(echo "$out" | jq -r '.display')
    assert_ne "null" "$display" "display should be present" &&
    [[ "$display" == *"Tracking stopped"* ]] || { echo "    FAIL: display should say tracking stopped"; return 1; }
}


# ═══════════════════════════════════════════════════════════════════════════
# H. cmd_auto_bump — display key
# ═══════════════════════════════════════════════════════════════════════════

test_auto_bump_start_has_display() {
    local repo
    repo=$(create_semver_repo)
    trap "cleanup_test_repo '$repo'" RETURN

    local out
    out=$(cd "$repo" && "$CLI" auto-bump start --confirm true)

    local display
    display=$(echo "$out" | jq -r '.display')
    assert_ne "null" "$display" "display should be present" &&
    [[ "$display" == *"Auto-bump enabled"* ]] || { echo "    FAIL: display should say auto-bump enabled"; return 1; }
}

test_auto_bump_start_no_confirm_has_questions() {
    local repo
    repo=$(create_semver_repo)
    trap "cleanup_test_repo '$repo'" RETURN

    local out
    out=$(cd "$repo" && "$CLI" auto-bump start)

    local q_len
    q_len=$(echo "$out" | jq '.questions | length')
    [ "$q_len" -gt 0 ] || { echo "    FAIL: should return questions when --confirm not provided"; return 1; }

    local confirm_q
    confirm_q=$(echo "$out" | jq '.questions[] | select(.id == "auto_bump_confirm")')
    assert_ne "" "$confirm_q" "should have auto_bump_confirm question"
}

test_auto_bump_stop_has_display() {
    local repo
    repo=$(create_semver_repo)
    trap "cleanup_test_repo '$repo'" RETURN

    # Enable first
    cd "$repo" && "$CLI" auto-bump start --confirm true > /dev/null

    local out
    out=$(cd "$repo" && "$CLI" auto-bump stop)

    local display
    display=$(echo "$out" | jq -r '.display')
    assert_ne "null" "$display" "display should be present" &&
    [[ "$display" == *"disabled"* ]] || { echo "    FAIL: display should say disabled"; return 1; }
}


# ═══════════════════════════════════════════════════════════════════════════
# I. cmd_repair_diagnose — display and questions
# ═══════════════════════════════════════════════════════════════════════════

test_repair_diagnose_all_pass_display() {
    local repo
    repo=$(create_semver_repo)
    trap "cleanup_test_repo '$repo'" RETURN

    local out
    out=$(cd "$repo" && "$CLI" repair diagnose)

    local display
    display=$(echo "$out" | jq -r '.display')
    assert_ne "null" "$display" "display should be present" &&
    [[ "$display" == *"Nothing to repair"* ]] || { echo "    FAIL: display should say nothing to repair"; return 1; }
}

test_repair_diagnose_failure_has_display_and_questions() {
    local repo
    repo=$(create_semver_repo)
    trap "cleanup_test_repo '$repo'" RETURN

    # Delete tag to create a failure
    git -C "$repo" tag -d v1.0.0

    local out
    out=$(cd "$repo" && "$CLI" repair diagnose)

    local display
    display=$(echo "$out" | jq -r '.display')
    [[ "$display" == *"issue"* ]] || { echo "    FAIL: display should mention issues"; return 1; }

    # Each repair should have a question object
    local first_repair_q
    first_repair_q=$(echo "$out" | jq '.repairs_needed[0].question')
    assert_ne "null" "$first_repair_q" "repair should have question object" &&

    local q_id
    q_id=$(echo "$first_repair_q" | jq -r '.id')
    assert_ne "null" "$q_id" "question should have id" &&

    local q_opts
    q_opts=$(echo "$first_repair_q" | jq '.options | length')
    [ "$q_opts" -gt 0 ] || { echo "    FAIL: question should have options"; return 1; }
}


# ═══════════════════════════════════════════════════════════════════════════
# J. cmd_repair_execute — display key
# ═══════════════════════════════════════════════════════════════════════════

test_repair_execute_has_display() {
    local repo
    repo=$(create_semver_repo)
    trap "cleanup_test_repo '$repo'" RETURN

    # Delete tag, then repair
    git -C "$repo" tag -d v1.0.0

    local out
    out=$(cd "$repo" && "$CLI" repair execute create-tag --version v1.0.0)

    local display
    display=$(echo "$out" | jq -r '.display')
    assert_ne "null" "$display" "display should be present" &&
    [[ "$display" == *"Repair"* ]] || { echo "    FAIL: display should mention Repair"; return 1; }
}


# ═══════════════════════════════════════════════════════════════════════════
# K. cmd_tracking_restore_tags — display key
# ═══════════════════════════════════════════════════════════════════════════

test_tracking_restore_tags_has_display() {
    local repo
    repo=$(create_semver_repo)
    trap "cleanup_test_repo '$repo'" RETURN

    # Stop tracking (archives tags)
    cd "$repo" && "$CLI" tracking stop-execute --archive version,changelog,tags > /dev/null

    # Now restore
    local out
    out=$(cd "$repo" && "$CLI" tracking restore-tags)

    local display
    display=$(echo "$out" | jq -r '.display')
    assert_ne "null" "$display" "display should be present" &&
    [[ "$display" == *"Tags restored"* ]] || { echo "    FAIL: display should say Tags restored"; return 1; }
}
