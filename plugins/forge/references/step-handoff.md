# Step Handoff Format

Specification for handoff documents written between pipeline steps to enable cold-start resumption after context clearing.

## Purpose

Each step writes a handoff document before triggering freshen. The next step reads this document on resumption to restore essential context without re-reading the entire conversation history.

**The handoff is mandatory, not best-effort.** After `/clear`, it is the only source of session knowledge. If the handoff is missing on resumption, the orchestrator MUST pause and ask the user how to proceed via `AskUserQuestion` rather than continuing with degraded context.

## File Location

`.forge/handoffs/handoff-<step>.md` where `<step>` is the step name (e.g., `interrogate`, `research`, `design`).

Handoff files are version-controlled (committed as part of the step exit protocol).

## Step Exit Protocol

Every orchestrated step follows the same exit pattern:

1. **Write output artifacts** to `.forge/`
2. **Write handoff**: `.forge/handoffs/handoff-<step>.md` with full context for next step
3. **Commit**: `git add .forge/ && git commit -m "forge(<step>): <summary>"`
4. **Queue freshen**: `bash plugins/freshen/bin/freshen.sh queue "<next-command>" --source forge --summary "<step summary>"`
   - Use the specific next step command when the transition is deterministic (e.g., `/forge research --orchestrated` after interrogate)
   - Use `/forge continue` when the next step depends on runtime state (e.g., after triage, review/validate, execute completion)
   - The `--summary` should be a brief, human-readable progress line describing what just completed
   - If freshen fails (no tmux), fall back to manual instructions:
     ```
     ---
     **Step complete.** All artifacts committed.

     To continue with fresh context:
     1. Run `/clear`
     2. Run `/forge continue`

     I'll pick up right where we left off.
     ---
     ```
5. **STOP** — End response immediately. Do not proceed inline.

## Handoff Format

```markdown
# Handoff: <Step Name> Complete

## Timestamp
[ISO 8601]

## Artifacts Produced
- [files written this step]

## Key Decisions
[Decisions this step made that downstream must respect]

## Context for Next Step
[What the next step specifically needs — replaces conversation context]

## Working Context (execution-phase steps only)
### Patterns Established
### Micro-Decisions
### Code Landmarks
### Test State

## Pipeline State
- Fix cycle: N / max
- Yolo mode: true/false
- Team roster: [active agents]
- ESCALATE stories pending: [count]

## Open Questions
[Unresolved items]
```

## Step-Specific Content

### Interrogate Handoff

| Section | Content |
|---------|---------|
| Key Decisions | Vision statement, core problem, scope boundaries |
| Context for Next Step | Top 5-7 requirements, challenged assumptions, research areas, existing solutions mentioned, user preferences/constraints |
| Open Questions | Questions for research to answer, unvalidated assumptions |

### Research Handoff

| Section | Content |
|---------|---------|
| Key Decisions | Existing solutions user chose to use/ignore, technology preferences |
| Context for Next Step | Research summary, recommended stack, patterns to follow, pitfalls, team roster recommendation |
| Open Questions | Design questions research could not resolve |

### Design Handoff

| Section | Content |
|---------|---------|
| Key Decisions | Architecture overview, key trade-offs, per-section user approvals |
| Context for Next Step | Component count and responsibilities, interface contracts, security/accessibility requirements, complexity areas, inter-component dependencies |
| Open Questions | Implementation questions deferred to planning |

### Plan Handoff

| Section | Content |
|---------|---------|
| Key Decisions | Plan approved, wave/task counts, test strategy |
| Context for Next Step | Plan structure summary, critical dependencies, risk highlights |
| Open Questions | Execution preferences |

### Decompose Handoff

| Section | Content |
|---------|---------|
| Key Decisions | Story count, dependency structure, DAG validation |
| Context for Next Step | Story-to-task mapping summary, wave ordering |
| Open Questions | Any ambiguous task boundaries |

### Execute Handoff

| Section | Content |
|---------|---------|
| Key Decisions | Stories completed, retry patterns, blocked stories |
| Context for Next Step | What was built, code patterns established |
| Working Context | Patterns, micro-decisions, code landmarks, test state (REQUIRED) |
| Open Questions | Any blocked stories needing user input |

### Review/Validate Handoff

| Section | Content |
|---------|---------|
| Key Decisions | Critical findings, gap severity assessments |
| Context for Next Step | Report summaries, recommended FIX/ESCALATE splits |
| Open Questions | Ambiguous findings needing triage |

### Triage Handoff

| Section | Content |
|---------|---------|
| Key Decisions | FIX vs ESCALATE decisions, escalate story IDs |
| Context for Next Step | FIX items for plan step, ESCALATE stories in storyhook |
| Pipeline State | Fix cycle count, yolo mode |

### Document Handoff

| Section | Content |
|---------|---------|
| Key Decisions | Documentation scope, files created |
| Context for Next Step | Pipeline summary for user review, ESCALATE status |
| Pipeline State | ESCALATE stories pending count |

## Missing Handoff on Resumption

If the orchestrator resumes and the expected handoff file is missing:

1. Do NOT silently continue with degraded context
2. Use `AskUserQuestion`:
   - **header:** "Missing Handoff"
   - **question:** "The handoff document from the previous step is missing (`.forge/handoffs/handoff-<step>.md`). Without it, I'll be working with limited context about decisions and rationale from the prior step. The artifacts themselves are intact."
   - **options:**
     - "Continue anyway (Recommended)" / "Proceed using only the artifact files — I can fill in context if needed. Pros: unblocks the pipeline immediately. Cons: decisions and rationale from the prior step may be lost."
     - "Let me create it" / "I'll write the handoff document manually, then re-invoke. Pros: restores full context. Cons: requires user effort and knowledge of the handoff format."
     - "Start this step over" / "Re-run the previous step to regenerate the handoff. Pros: guaranteed correct context. Cons: re-does work that already completed."
3. If "Continue anyway" -> proceed but note in plain text which context may be incomplete

## Step Rollback

If a user wants to redo a step, delete the artifacts for that step to reset it. Commits after each step make rollback safe — earlier steps are already committed.

| Rollback to... | Delete these files |
|----------------|-------------------|
| Interrogate | All of `.forge/` |
| Research | `.forge/research/`, `.forge/TEAM.md`, `.forge/handoffs/handoff-interrogate.md` |
| Design | `.forge/DESIGN.md`, `.forge/handoffs/handoff-research.md` |
| Plan | `.forge/PLAN.md`, `.forge/handoffs/handoff-design.md` |
| Decompose | `.forge/plan-mapping.json`, `.forge/handoffs/handoff-plan.md` |
| Execute | Stories (via storyhook), `.forge/handoffs/handoff-decompose.md` |
| Review+Validate | `.forge/REVIEW-REPORT.md`, `.forge/VALIDATE-REPORT.md`, `.forge/handoffs/handoff-execute.md` |
| Triage | `.forge/TRIAGE.md`, `.forge/handoffs/handoff-review.md`, `.forge/handoffs/handoff-validate.md` |
| Document | `.forge/DOCUMENTATION.md`, `.forge/handoffs/handoff-triage.md` |
| Deploy | `.forge/DEPLOY-APPROVAL.md`, `.forge/COMPLETION.md`, `.forge/handoffs/handoff-document.md` |

After deleting, re-invoke `/forge continue` — the state detection picks up from the correct step.
