# Pilot Plugin

Unified idea-to-deployment pipeline for Claude Code. Takes a raw idea through interrogation, research, design, planning, autonomous execution, review, validation, triage, documentation, and deployment — with freshen-based context clearing between every step.

## Overview

Pilot replaces the separate ideate and pilot plugins with a single unified pipeline:

```
Interrogate -> Research -> Design -> Plan -> Decompose -> Execute
                                                            |
                                                 Review || Validate (parallel)
                                                            |
                                                         Triage
                                                            |
                                              FIX items? -> Plan (loop, max 3 / 10 yolo)
                                              No FIX    -> Document
                                                            |
                                                         PAUSE (always)
                                                            |
                                              ESCALATE? -> User reviews -> Plan
                                              None      -> Deploy (with permission)
```

## Commands

| Command | Purpose |
|---------|---------|
| `/pilot` | Detect state and continue pipeline |
| `/pilot continue` | Same as above |
| `/pilot <step>` | Invoke a specific step standalone |
| `/pilot status` | Pipeline dashboard |
| `/pilot stop` | Graceful stop with handoff |
| `/pilot --yolo` | FIX everything, never ESCALATE |

## Pipeline Steps (11)

| # | Step | Input | Output |
|---|------|-------|--------|
| 1 | Interrogate | User's idea | `IDEA.md` |
| 2 | Research | `IDEA.md` | `research/SUMMARY.md` + `TEAM.md` |
| 3 | Design | `IDEA.md`, research | `DESIGN.md` |
| 4 | Plan | `IDEA.md`, `DESIGN.md` | `PLAN.md` |
| 5 | Decompose | `PLAN.md`, `DESIGN.md` | stories + `plan-mapping.json` |
| 6 | Execute | stories, mapping | Implemented code |
| 7 | Review | code, `DESIGN.md` | `REVIEW-REPORT.md` |
| 8 | Validate | code, `PLAN.md` | `VALIDATE-REPORT.md` |
| 9 | Triage | reports | `TRIAGE.md` |
| 10 | Document | all artifacts | `DOCUMENTATION.md` |
| 11 | Deploy | approval | `COMPLETION.md` |

## Architecture

### State Machine Router

The orchestrator detects pipeline state from artifacts on disk and dispatches to the correct step. No conversation state is needed — everything is derived from `.pilot/` contents.

### Step Exit Protocol

Every step follows the same pattern:
1. Write artifacts to `.pilot/`
2. Write handoff to `.pilot/handoffs/handoff-<step>.md`
3. Commit
4. Queue freshen (`/clear` + `/pilot continue`)
5. STOP

### Agent Roster (15 agents)

12 migrated from ideate + pilot, 3 new:
- **reviewer** — static gap/defect analysis
- **validator** — test hardening
- **triager** — FIX/ESCALATE deliberation

### FIX/ESCALATE Loop

After execution, Review + Validate run in parallel. Triage deliberates on findings:
- **FIX**: auto-fix via Plan -> Decompose -> Execute -> Review -> Validate -> Triage (max 3 cycles, 10 in yolo mode)
- **ESCALATE**: user reviews context and recommendations for each item

### Safety

- Canary mode: first N stories require user approval
- Runaway safeguards: max sessions, max retries, max fix cycles
- Deploy: never without explicit user permission
- Always pauses after Document step for user review
