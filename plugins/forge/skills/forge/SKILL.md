---
name: forge
description: Unified idea-to-deployment pipeline — interrogation, research, design, planning, autonomous execution, review, validation, triage, documentation, and deployment. State-machine router dispatching to 11 pipeline skills with freshen-based context clearing between steps.
argument-hint: continue | interrogate | research | design | plan | decompose | execute | review | validate | triage | document | deploy | status | stop | [idea description]
---

# Forge: Unified Pipeline

You are the forge orchestrator — a thin state-machine router that detects pipeline state from artifacts, loads the appropriate skill, and dispatches. Each pipeline step is a separate skill that reads its inputs from `.forge/`, writes its outputs, and exits.

**Core references (load on demand, not all at once):**
- `references/step-handoff.md` — Step exit protocol and handoff format
- `references/storyhook-contract.md` — Story CLI command mapping
- `references/execution-loop.md` — Autonomous execution loop
- `references/session-locking.md` — Lock protocol
- `references/recovery-protocol.md` — Resume/recovery sequence
- `references/auto-resume.md` — Freshen-based auto-resume
- `references/questioning.md` — Interrogation questioning methodology
- `references/team-roles.md` — Agent team roles and spawning philosophy

## Hard Rules

1. **Storyhook is authoritative** for story-level state. Never duplicate story state in forge files.
2. **One story at a time** through the generator-evaluator loop. No parallel story execution.
3. **Generator does NOT commit.** Commits happen only after evaluation passes.
4. **Evaluator has NO Write/Edit tools.** It judges, never fixes.
5. **Clean working tree** before each generator spawn: `git checkout .`
6. **State files re-read every iteration** from disk. Never rely on in-memory state.
7. **Structured JSON** for all evaluator feedback stored in storyhook comments. Never raw freeform text.
8. **`jq` for JSON construction** in all shell scripts. Never `printf` with string escaping.
9. **One question at a time** via `AskUserQuestion`. Every user question uses exactly 1 `AskUserQuestion` call.
10. **Never proceed inline between steps.** Every step ends with the Step Exit Protocol (handoff → commit → freshen → STOP). Exception: Review + Validate run in parallel within a single step dispatch.

## Legacy Migration Detection

Before routing, check for legacy ideate artifacts:

If `.planning/ideate/` exists with artifacts (IDEA.md, DESIGN.md, PLAN.md, etc.):
1. Use AskUserQuestion:
   - **header:** "Legacy Data"
   - **question:** "Found legacy ideate artifacts in `.planning/ideate/`. These are from the deprecated ideate plugin. Would you like to migrate them to the unified pipeline?"
   - **options:**
     - "Migrate to .forge/ (Recommended)" / "Copy legacy artifacts into the unified pipeline. Pros: cleanest path, single source of truth. Cons: original .planning/ideate/ files remain (manual cleanup)."
     - "Ignore — start fresh" / "Discard legacy work and begin from scratch. Pros: no legacy baggage. Cons: loses prior interrogation/design work."
     - "Keep both — I'll manage manually" / "Leave legacy in place, proceed with empty .forge/. Pros: full control, no data movement. Cons: two artifact trees to track."
2. If "Migrate":
   - Copy `.planning/ideate/IDEA.md` → `.forge/IDEA.md`
   - Copy `.planning/ideate/research/` → `.forge/research/`
   - Copy `.planning/ideate/DESIGN.md` → `.forge/DESIGN.md`
   - Copy `.planning/ideate/PLAN.md` → `.forge/PLAN.md`
   - Commit: `git add .forge/ && git commit -m "forge: migrate legacy ideate artifacts to .forge/"`
   - Resume with state detection on `.forge/`
3. If "Ignore" → proceed as normal (empty `.forge/` → interrogate)
4. If "Keep both" → proceed as normal, user manages legacy artifacts

Only check this once — if `.forge/` already has artifacts, skip the migration check.

## Command Router

Parse the user's message to determine the subcommand. If the input is a bare idea description (no recognized subcommand), treat it as `/forge interrogate <idea>`.

### Recognized Commands

| Command | Action |
|---------|--------|
| `/forge` (no args) | Same as `continue` |
| `/forge continue` | Detect state from artifacts, dispatch to next step |
| `/forge resume` | Alias for `continue` — detect state from artifacts, dispatch to next step |
| `/forge <step>` | Direct invocation of a step (standalone mode) |
| `/forge <step> --orchestrated` | Step invoked by orchestrator (uses step exit protocol) |
| `/forge status` | Show pipeline dashboard |
| `/forge stop` | Graceful stop — write handoff, release lock, cancel freshen |
| `/forge --yolo` | Set yolo mode in config, then continue |

### Flags

- `--yolo` — FIX everything during triage, never ESCALATE, skip deliberation, 10 max fix cycles
- `--orchestrated` — Internal flag passed when dispatching to skills. Skills use this to decide exit behavior (step exit protocol vs. clean return to user).

---

## State Detection (`continue`)

On every `continue` invocation:

1. Read most recent handoff from `.forge/handoffs/` (if any exist)
2. Scan `.forge/` artifacts using the table below (bottom-up scan, **first match wins**)
3. Read the SKILL.md for the detected next step
4. Dispatch to that step with `--orchestrated`

### Artifact Scan Table

| Artifacts Found | Next State | Dispatch To |
|----------------|------------|-------------|
| `COMPLETION.md` | complete | Done — report completion |
| `DEPLOY-APPROVAL.md` | deploy | `deploy --orchestrated` |
| `DOCUMENTATION.md` + no ESCALATE stories pending | pause | Prompt user for deploy permission |
| `DOCUMENTATION.md` + ESCALATE stories pending | pause | ESCALATE review loop (see below) |
| `TRIAGE.md` with FIX items + fix cycle < max | fix_loop | `plan --orchestrated` (fix cycle) |
| `TRIAGE.md` with no FIX items | document | `document --orchestrated` |
| `REVIEW-REPORT.md` + `VALIDATE-REPORT.md` | triage | `triage --orchestrated` |
| All stories done (query storyhook) | review_validate | `review --orchestrated` + `validate --orchestrated` (parallel) |
| `plan-mapping.json` + stories not all done | execute | `execute --orchestrated` |
| `PLAN.md` + no `plan-mapping.json` | decompose | `decompose --orchestrated` |
| `DESIGN.md` + no `PLAN.md` | plan | `plan --orchestrated` |
| `research/SUMMARY.md` + no `DESIGN.md` | design | `design --orchestrated` |
| `IDEA.md` + no `research/SUMMARY.md` | research | `research --orchestrated` |
| Nothing in `.forge/` | interrogate | `interrogate --orchestrated` |

### State Detection Implementation

```
Read .forge/ directory listing

# Bottom-up scan (first match wins):
if exists .forge/COMPLETION.md → state = complete
elif exists .forge/DEPLOY-APPROVAL.md → state = deploy
elif exists .forge/DOCUMENTATION.md:
  check storyhook for ESCALATE stories → if pending: pause_escalate, else: pause_deploy
elif exists .forge/TRIAGE.md:
  read TRIAGE.md for FIX items
  read .forge/config.json for max_fix_cycles (or max_fix_cycles_yolo if yolo)
  read current fix cycle count from .forge/fix-cycles/
  if FIX items AND cycle < max → state = fix_loop
  elif no FIX items → state = document
elif exists .forge/REVIEW-REPORT.md AND exists .forge/VALIDATE-REPORT.md → state = triage
elif storyhook stories exist AND all done → state = review_validate
elif exists .forge/plan-mapping.json AND storyhook has non-done stories → state = execute
elif exists .forge/PLAN.md AND not exists .forge/plan-mapping.json → state = decompose
elif exists .forge/DESIGN.md AND not exists .forge/PLAN.md → state = design
elif exists .forge/research/SUMMARY.md AND not exists .forge/DESIGN.md → state = design
elif exists .forge/IDEA.md AND not exists .forge/research/SUMMARY.md → state = research
else → state = interrogate
```

### Fix Loop Handling

When entering a fix loop:
1. Archive current cycle: move `TRIAGE.md`, `PLAN.md`, `plan-mapping.json` to `.forge/fix-cycles/cycle-N/`
2. Increment fix cycle counter
3. Dispatch to `plan --orchestrated` with the FIX items as input

### ESCALATE Review Loop (Post-Document Pause)

When ESCALATE stories are pending after Document:
1. Summarize pipeline results and any deviations from the happy path
2. List FIX stories that were resolved and any FIX→ESCALATE promotions
3. For each ESCALATE story, use `AskUserQuestion` to present:
   - The finding description
   - All solution options with pros/cons (from the triage report). Mark the team's recommended option with `(Recommended)` appended to its label.
   - Ask user to choose an approach
4. After all ESCALATE stories are reviewed → dispatch to `plan --orchestrated` with user decisions

### Deploy Permission Gate

When no ESCALATE stories remain after Document:
1. Present pipeline summary
2. Use `AskUserQuestion`:
   - **header:** "Deploy?"
   - **question:** "Pipeline complete. Ready to deploy?"
   - **options:**
     - "Deploy now (Recommended)" / "Proceed to deployment. Pros: completes the pipeline end-to-end. Cons: deployment is irreversible for some targets."
     - "Not yet — let me review first" / "Pause so I can inspect the codebase. Pros: human verification before shipping. Cons: delays completion."
     - "Done — no deployment needed" / "Mark pipeline complete without deploying. Pros: skips unnecessary deployment step. Cons: no automated deployment or smoke test."
3. If "Deploy now" → write `.forge/DEPLOY-APPROVAL.md`, dispatch to `deploy --orchestrated`
4. If "Not yet" → exit cleanly, user re-invokes when ready
5. If "Done" → write `.forge/COMPLETION.md`, report completion

---

## Direct Invocation (Standalone Mode)

Any skill can be invoked directly: `/forge <step> [args]`

In standalone mode (no `--orchestrated` flag):
- Skill reads inputs from `.forge/`
- Skill writes outputs to `.forge/`
- Skill exits cleanly to the user (no freshen, no step exit protocol)
- User decides what to do next

---

## Step Exit Protocol

**Read**: `references/step-handoff.md`

Every orchestrated step follows the same exit pattern:

1. Write output artifacts to `.forge/`
2. Write handoff: `.forge/handoffs/handoff-<step>.md` with full context for next step
3. Commit: `git add .forge/ && git commit -m "forge(<step>): <summary>"`
4. Queue freshen: `bash plugins/freshen/bin/freshen.sh queue "<next-command>" --source forge --summary "<step summary>"`
   - Use the specific next step command when deterministic (e.g., `/forge research --orchestrated`)
   - Use `/forge continue` when next step depends on runtime state
   - If freshen fails (no tmux), fall back to manual instructions
5. **STOP** — end response immediately. Do not proceed inline.

---

## `/forge status`

Show pipeline dashboard:

1. Read `.forge/` artifact listing to determine current step
2. Read `.forge/config.json` for settings
3. If execution phase: read `.forge/state.json` for runtime counters, query storyhook for story states
4. List recent handoffs from `.forge/handoffs/`

Display:
```
## Forge Pipeline Status

**Current step**: [detected step]
**Mode**: [normal | yolo]

### Artifacts
- IDEA.md: [exists/missing]
- research/SUMMARY.md: [exists/missing]
- DESIGN.md: [exists/missing]
- PLAN.md: [exists/missing]
- plan-mapping.json: [exists/missing]
- [etc.]

### Execution Progress (if in execute/review/validate/triage)
[Story counts by state, retry counters, session count]

### Fix Cycles
[Current cycle N / max, history of prior cycles]

### Recent Handoffs
[Last 3 handoff filenames with timestamps]
```

---

## `/forge stop`

Graceful stop:

1. If execution phase is active:
   - Write handoff following `references/handoff-format.md`
   - Update `.forge/state.json`: set `status: "paused"`
   - Release lock: delete `.forge/lock.json`
2. Cancel pending freshen signal: `bash plugins/freshen/bin/freshen.sh cancel --source forge`
3. Report: "Pipeline stopped. Run `/forge continue` to resume."

---

## Settings

`.forge/config.json` (created with defaults on first run):

```json
{
  "yolo": false,
  "max_fix_cycles": 3,
  "max_fix_cycles_yolo": 10,
  "when_in_doubt": "escalate",
  "max_retries": 4,
  "max_stories_per_session": 1,
  "max_sessions": 200,
  "max_total_retries": 20,
  "heartbeat_window_minutes": 30
}
```

`--yolo` overrides at runtime (sets `yolo: true` in config for the session).

---

## Pipeline Skills

Each skill is a separate SKILL.md under `skills/<step>/`. The orchestrator dispatches by reading the skill file and following its instructions.

| # | Skill | Input | Output |
|---|-------|-------|--------|
| 1 | `interrogate` | User's idea | `.forge/IDEA.md` |
| 2 | `research` | `IDEA.md` | `.forge/research/SUMMARY.md` + `.forge/TEAM.md` |
| 3 | `design` | `IDEA.md`, `research/SUMMARY.md`, `TEAM.md` | `.forge/DESIGN.md` |
| 4 | `plan` | `IDEA.md`, `DESIGN.md` | `.forge/PLAN.md` |
| 5 | `decompose` | `PLAN.md`, `DESIGN.md` | stories + `.forge/plan-mapping.json` |
| 6 | `execute` | `plan-mapping.json`, stories | Implemented code |
| 7 | `review` | Implemented code, `DESIGN.md` | `.forge/REVIEW-REPORT.md` |
| 8 | `validate` | Implemented code, `PLAN.md` | `.forge/VALIDATE-REPORT.md` |
| 9 | `triage` | `REVIEW-REPORT.md`, `VALIDATE-REPORT.md` | `.forge/TRIAGE.md` |
| 10 | `document` | All artifacts, implemented code | `.forge/DOCUMENTATION.md` |
| 11 | `deploy` | `DEPLOY-APPROVAL.md` | `.forge/COMPLETION.md` |

---

## Agent Roster (15 agents)

| Agent | Used By |
|-------|---------|
| `domain-researcher` | interrogate (recon), research |
| `software-architect` | design, review, execute (drift check) |
| `senior-engineer` | execute (available via roster) |
| `qa-engineer` | plan, validate, triage |
| `ux-designer` | design (conditional) |
| `project-manager` | plan, validate, triage, decompose |
| `devils-advocate` | design, plan, review, triage |
| `security-researcher` | design (conditional), review (conditional) |
| `accessibility-engineer` | design (conditional), review (conditional) |
| `technical-writer` | document |
| `generator` | execute |
| `evaluator` | execute |
| `reviewer` | review |
| `validator` | validate |
| `triager` | triage |

The research step produces `.forge/TEAM.md` recommending which conditional agents to activate.

---

## Artifact Namespace

```
.forge/
  # Config (version-controlled)
  config.json
  plan-mapping.json
  team-roster.json

  # Step outputs (version-controlled)
  IDEA.md
  research/SUMMARY.md
  TEAM.md
  DESIGN.md
  PLAN.md
  REVIEW-REPORT.md
  VALIDATE-REPORT.md
  TRIAGE.md
  DOCUMENTATION.md
  DEPLOY-APPROVAL.md
  COMPLETION.md

  # Fix cycle archives (version-controlled)
  fix-cycles/cycle-N/
    TRIAGE.md
    PLAN.md
    plan-mapping.json

  # Handoff archive (version-controlled)
  handoffs/
    handoff-interrogate.md
    handoff-research.md
    ...

  # Runtime (gitignored)
  state.json
  lock.json
  verdicts.jsonl
```

---

## Resumption

If the user invokes `/forge` or `/forge continue` at any point:
1. The orchestrator scans artifacts to detect state
2. Reads the most recent handoff from `.forge/handoffs/`
3. If the expected handoff is missing → pause and ask user via `AskUserQuestion` (missing-handoff protocol from `references/step-handoff.md`)
4. Dispatches to the detected next step

This makes the pipeline fully resumable from any point. The orchestrator never needs to know which step just finished — it derives everything from artifacts + handoff.
