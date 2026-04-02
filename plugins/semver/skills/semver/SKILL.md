---
name: semver
description: Use when the user wants to manage semantic versioning for their project. Handles version tracking (start/stop), version bumping (major/minor/patch) with changelog generation, reading current version, auto-bump configuration, and sync integrity validation/repair. Commands are /semver current, /semver bump, /semver tracking, /semver auto-bump, /semver validate, and /semver repair.
argument-hint: <current | bump <major|minor|patch> [--force] | tracking <start [options]|stop> | auto-bump <start|stop> | validate | repair>
---

# Semantic Versioning Orchestrator

You manage semantic versioning by delegating deterministic work to the CLI tool and handling user interaction.

**CLI path:** `python3 ${CLAUDE_PLUGIN_ROOT}/bin/semver-cli`

## Hard Rules

1. **Always parse CLI JSON output** before reporting to the user.
2. **Every question to the user MUST use `AskUserQuestion`** with exactly 1 question per call.
3. **Never fabricate changelog entries** — the CLI generates them from git log.
4. **When CLI returns `ok: false`**, report the `message` to the user and stop.
5. **Mark bump source** — pass `--source manual` for explicit user bumps, `--source auto` for auto-bump hook, `--source force` if `--force` was used.
6. **Do NOT invoke `/semver bump` from within PROMPT_HOOK.md instructions** — this causes infinite recursion.

## Command Router

Parse the ARGUMENTS string to determine which command to run:

| Argument starts with | Command |
|---------------------|---------|
| `current` or empty | `/semver current` |
| `bump` | `/semver bump` |
| `tracking` | `/semver tracking` |
| `auto-bump` | `/semver auto-bump` |
| `validate` or `check` | `/semver validate` |
| `repair` or `fix` | `/semver repair` |
| Anything else | Show usage help |

**Usage help:**
```
/semver current                        — Show current version and status
/semver bump <major|minor|patch>       — Bump version, generate changelog, commit (+ tag if enabled)
/semver bump <major|minor|patch> --force — Bump even with no changes since last version change
/semver tracking start                 — Initialize version tracking
/semver tracking start [options]       — Options: --version <ver>, --prefix <v|none>, --no-tags, --changelog <grouped|flat>, --branch <name>, --restore-tags
/semver tracking stop                  — Archive and disable version tracking
/semver auto-bump start                — Enable automatic version bumps on push
/semver auto-bump stop                 — Disable automatic version bumps
/semver validate                       — Verify VERSION/CHANGELOG/tag sync integrity
/semver repair                         — Guided repair of sync issues
```

---

## Command: `/semver current`

Run: `python3 ${CLAUDE_PLUGIN_ROOT}/bin/semver-cli current`

Parse JSON. Report:
- If `tracking` is false: report the `message` and stop.
- Current version (or "No version set yet — run `/semver bump` to set the first version.")
- Commits since last version change and date
- Auto-bump status, target branch, git tagging status

---

## Command: `/semver bump <major|minor|patch> [--force]`

Extract `BUMP_TYPE` (major/minor/patch) and `FORCE` flag from arguments.

### Step 1: Gather

Run: `python3 ${CLAUDE_PLUGIN_ROOT}/bin/semver-cli bump gather <BUMP_TYPE> [--force]`

Parse JSON:
- If `ok` is false: report the `message` and stop.
- If `no_commits` is true (and not force): report the `message` and stop.

### Step 2: Handle first version

If `version_exists` is false:
- Use AskUserQuestion:
  - **header:** "First version"
  - **question:** "No version is set yet. What should the first version be?"
  - **options:** "v0.1.0 (Recommended)" / "v1.0.0" / "v0.0.1"
- Run: `python3 ${CLAUDE_PLUGIN_ROOT}/bin/semver-cli bump first-version <chosen>`
- Report result and stop.

### Step 3: Handle questions

Process `questions_needed` array from gather result:

**If `dirty_tree`:**
Use AskUserQuestion:
- **header:** "Dirty tree"
- **question:** "You have uncommitted changes: <list dirty_files>. What would you like to do?"
- **options:** "Include all in bump commit" / "Stash and bump clean" / "Cancel"
- If cancel: stop.

**If `wrong_branch`:**
Use AskUserQuestion:
- **header:** "Branch"
- **question:** "You're on branch `<current_branch>`, not `<target_branch>`. Bumping from a non-target branch means the tag may not be reachable from the target branch until merged. Proceed?"
- **options:** "Proceed anyway" / "Cancel"
- If cancel: stop.

**If `validation_failed`:**
Use AskUserQuestion:
- **header:** "Sync issue"
- **question:** "Validation found issues. Bumping on top of broken sync may compound the problem."
- **options:** "Run repair first" / "Bump anyway" / "Cancel"
- If repair: run `/semver repair`, then re-run this bump command.
- If cancel: stop.

### Step 4: Pre-bump PROMPT_HOOK

If `has_pre_bump_prompt_hook` is true: Read the file at `pre_bump_prompt_hook_path` and follow its instructions. Context: BUMP_TYPE, old_version, new_version from gather result. **Do NOT trigger `/semver bump`**. If instructions indicate abort, stop.

### Step 5: Execute

Build the command from user answers:
```
python3 ${CLAUDE_PLUGIN_ROOT}/bin/semver-cli bump execute <BUMP_TYPE> \
  --source <manual|force> \
  [--force] \
  [--dirty-action <include|stash|none>] \
  [--skip-validation] \
  [--overwrite-tag | --skip-tag] \
  --plugin-root ${CLAUDE_PLUGIN_ROOT}
```

Use `--source force` if `--force` was used, otherwise `--source manual`.
Map dirty tree answer: "Include all" → `--dirty-action include`, "Stash" → `--dirty-action stash`.
If user chose "Bump anyway" for validation: add `--skip-validation`.
If `tag_conflict` in gather result and user chooses overwrite: `--overwrite-tag`.

### Step 6: Post-bump PROMPT_HOOK

Parse execute result. If `post_hooks.prompt_hook` is not null, that is the content of the post-bump PROMPT_HOOK.md file. Follow its instructions. Context: BUMP_TYPE, old_version, new_version. **Do NOT trigger `/semver bump`**.

### Step 7: Report

If any `post_hooks.warnings` exist, report each warning.

Report:
- Previous version → New version
- Commits included
- Tag created/skipped/tagging disabled
- Changelog preview (from `changelog_preview`)

---

## Command: `/semver tracking start`

Run: `python3 ${CLAUDE_PLUGIN_ROOT}/bin/semver-cli tracking start [options]`

Pass through any user-provided options: `--version`, `--prefix`, `--no-tags`, `--changelog`, `--branch`, `--restore-tags`.

Parse JSON:
- If `action` is `already_active`: report the message and stop.
- If `action` is `archive_restore` and `questions_needed` contains `restore_tags`:
  - Use AskUserQuestion:
    - **header:** "Tags"
    - **question:** "The archive contains <tag count> version tags. Restore them?"
    - **options:** "Skip tag restoration (Recommended)" / "Restore tags"
  - If restore: run `python3 ${CLAUDE_PLUGIN_ROOT}/bin/semver-cli tracking restore-tags`
- Report: tracking enabled, target branch, tagging status, version (if set).

---

## Command: `/semver tracking stop`

### Step 1: Gather

Run: `python3 ${CLAUDE_PLUGIN_ROOT}/bin/semver-cli tracking stop-gather`

If `ok` is false: report error and stop.

### Step 2: Ask what to archive

Use AskUserQuestion:
- **header:** "Archive"
- **question:** "Which items to archive to VERSIONING_ARCHIVE.md before disabling tracking?"
- **options:** "VERSION file" / "CHANGELOG" / (only if git_tagging) "Git tags"
- **multiSelect:** true

### Step 3: Tag deletion (if tags selected and git_tagging)

If user selected tags:
Use AskUserQuestion:
- **header:** "Remote tags"
- **question:** "Delete version tags from the remote too? Warning: this affects all collaborators."
- **options:** "Delete local only (Recommended)" / "Delete local and remote" / "Don't delete tags"

### Step 4: Execute

```
python3 ${CLAUDE_PLUGIN_ROOT}/bin/semver-cli tracking stop-execute \
  --archive <comma-separated items> \
  --delete-tags <local|both|none>
```

Map: "Delete local only" → `--delete-tags local`, "Delete local and remote" → `--delete-tags both`, "Don't delete tags" → `--delete-tags none`.

Report results.

---

## Command: `/semver auto-bump start`

Use AskUserQuestion:
- **header:** "Confirm"
- **question:** "Should Claude ask you to confirm the bump level before executing?"
- **options:** "Yes — confirm first (Recommended)" / "No — fully automatic"

Run: `python3 ${CLAUDE_PLUGIN_ROOT}/bin/semver-cli auto-bump start --confirm <true|false>`

Report: auto-bump enabled, confirmation mode, target branch.

---

## Command: `/semver auto-bump stop`

Run: `python3 ${CLAUDE_PLUGIN_ROOT}/bin/semver-cli auto-bump stop`

Report result.

---

## Command: `/semver validate`

Run: `python3 ${CLAUDE_PLUGIN_ROOT}/bin/semver-cli validate`

Parse JSON. Format and report checks:
```
[semver] Validation results:
  [<STATUS>] <detail>
  ...
  Status: <summary>
```

If any FAIL: suggest "Run `/semver repair` to fix."

---

## Command: `/semver repair`

### Step 1: Diagnose

Run: `python3 ${CLAUDE_PLUGIN_ROOT}/bin/semver-cli repair diagnose`

If `all_pass` is true: report "All integrity checks passed." and stop.

### Step 2: Repair each failure

For each item in `repairs_needed`:

**`tag_missing`:**
Use AskUserQuestion:
- **header:** "Missing tag"
- **question:** "VERSION says `<version>` but no git tag exists."
- **options:** "Create tag + changelog entry" / "Revert VERSION to <latest_tag>" / "Skip"
- Execute chosen action:
  - Create: `python3 ${CLAUDE_PLUGIN_ROOT}/bin/semver-cli repair execute create-tag --version <version>`
  - Revert: `python3 ${CLAUDE_PLUGIN_ROOT}/bin/semver-cli repair execute revert-version --to <latest_tag>`

**`tag_wrong_commit`:**
Use AskUserQuestion:
- **header:** "Tag mismatch"
- **question:** "Tag and VERSION point to different commits."
- **options:** "Move tag to VERSION's commit" / "Revert VERSION to match tag" / "Skip"
- Execute chosen action:
  - Move: `python3 ${CLAUDE_PLUGIN_ROOT}/bin/semver-cli repair execute move-tag --version <version> --commit <version_commit>`
  - Revert: `python3 ${CLAUDE_PLUGIN_ROOT}/bin/semver-cli repair execute revert-version --to <version>`

**`changelog_missing`:**
Use AskUserQuestion:
- **header:** "Missing changelog"
- **question:** "Version `<version>` has no CHANGELOG entry."
- **options:** "Generate entry" / "Skip"
- Execute: `python3 ${CLAUDE_PLUGIN_ROOT}/bin/semver-cli repair execute generate-entry --version <version>`

### Step 3: Re-validate

Run: `python3 ${CLAUDE_PLUGIN_ROOT}/bin/semver-cli validate`

Report final status.
