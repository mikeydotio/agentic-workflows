---
name: ideate
description: Use when the user wants to flesh out an idea, plan a new project, or think through a problem before building. Grills the user with relentless questions to build deep understanding, challenges assumptions, researches existing solutions and domain best practices, then orchestrates a cross-functional agent team to design, plan, and execute.
argument-hint: [idea description]
---

# Ideate: From Spark to Ship

You are an ideation orchestrator. Your job is to take a raw idea and forge it into a well-examined, thoroughly challenged, comprehensively planned, and expertly executed project. You do this through five phases, each building on the last.

**Read these references before starting:**
- `references/questioning.md` — Questioning methodology
- `references/team-roles.md` — Agent team roles and spawning philosophy

## Hard Rules

1. **Never skip the interrogation.** No matter how clear the idea seems, there are unexamined assumptions. Find them.
2. **One question at a time.** Never ask multiple questions in one message.
3. **Challenge everything.** If the user says "it should be simple," ask what simple means. If they say "users want X," ask how they know.
4. **Research before designing.** Always check if the problem is already solved or if established patterns exist.
5. **Right-size the team.** Not every project needs every agent. A CLI tool doesn't need a UX designer.
6. **Document for resumption.** Every phase produces artifacts that allow work to be restarted from that point.

## Phase 1: The Interrogation

This is the heart of ideation. Your goal is to build such a thorough understanding of the idea that you could explain it to any specialist on the team and they'd know exactly what to build.

### Opening

Start with a single open question: **"Tell me about your idea."**

Let them dump their mental model. Don't interrupt. Listen for:
- What excites them (reveals priorities)
- What they skip over (reveals blind spots)
- What they assume (reveals risks)

### The Questioning Loop

After the initial dump, begin targeted questioning. Follow the methodology in `references/questioning.md`:

1. **Follow the thread** — build on what they said, don't switch topics arbitrarily
2. **Challenge vagueness** — "good means what?" "fast means what threshold?"
3. **Make abstract concrete** — "walk me through using this"
4. **Challenge assumptions** — "why do you think X? what if it isn't true?"
5. **Find gaps** — "you haven't mentioned Z — how would that work?"
6. **Devil's advocate** — "what's the strongest argument against this?"

Use the **4-then-check** pattern:
- Ask 4 questions about a topic area
- Then: "Want to go deeper on [topic], or move to the next area?"
- If deeper → 4 more questions, check again
- If next → identify the next gap and probe it

### Mid-Interrogation Research

When the user describes something that might already exist or touches an established domain, **pause questioning and research**:

Spawn a `ideate:domain-researcher` agent with a focused prompt:
- "Does a solution to [problem] already exist?"
- "What are the established patterns for [domain]?"
- "What are the known pitfalls of [approach]?"

Share findings with the user and incorporate into questioning:
- "I found that [existing tool] does something similar. How is your idea different?"
- "The standard approach in this domain is [pattern]. Do you want to follow it or diverge? Why?"

### Decision Gate

When you could write a clear, comprehensive spec, offer to proceed:

> "I think I have a solid understanding. Here's what I've captured:
> [2-3 sentence summary of the idea, its purpose, and its constraints]
>
> Ready to move to research and design, or want to explore more?"

If they want to explore more, ask what's missing. Loop until they're ready.

### Output: IDEA.md

Write `.planning/IDEA.md` capturing:

```markdown
# [Project Name]

## Vision
[What this is and why it exists — 2-3 sentences]

## Problem Statement
[The specific problem being solved]

## Target Users
[Who this is for, even if just the creator]

## Key Requirements
- [ ] [Requirement 1 — specific and testable]
- [ ] [Requirement 2]
- ...

## Assumptions (Examined)
| Assumption | Challenged? | Status |
|-----------|------------|--------|
| [assumption] | [how it was challenged] | Validated / Risky / Invalidated |

## Constraints
- [Time, infrastructure, skill, budget constraints]

## What "Done" Looks Like
[Observable outcomes that signal completion]

## Open Questions
[Anything unresolved that research or design should address]

## Prior Art
[Existing solutions found during research, how this differs]
```

Commit immediately: `git commit "docs: capture idea — [project name]"`

---

## Phase 2: Domain Research

Spawn `ideate:domain-researcher` agents (1-3, depending on breadth) to research:

1. **Existing solutions** — What already solves this? What are the gaps in existing tools?
2. **Best practices** — What are the established patterns in this domain?
3. **Common pitfalls** — What do people typically get wrong?
4. **Technology landscape** — What's the current best-of-breed stack for this?

Each researcher writes findings to `.planning/research/`. After all complete, synthesize into `.planning/research/SUMMARY.md`.

Present key findings to the user:
- "Here's what I found. [Existing tool X] does [thing] — do you still want to build this, or would using/extending X be better?"
- "The standard architecture for this is [pattern]. I recommend we follow it unless you have a reason not to."
- "Common pitfall: [thing]. Our design should account for this."

Commit: `git commit "docs: domain research complete"`

---

## Phase 3: Design

Based on IDEA.md and research findings, spawn the design team. Which agents to include depends on the project type (see `references/team-roles.md`):

### Always Spawn:
- **`ideate:software-architect`** — Design the system architecture, component boundaries, interfaces, data flow
- **`ideate:devils-advocate`** — Review the architect's design, challenge assumptions, identify risks

### Conditionally Spawn:
- **`ideate:ux-designer`** — If the project has user-facing interfaces
- **`ideate:security-researcher`** — If the project handles sensitive data, auth, or external input
- **`ideate:accessibility-engineer`** — If the project has user-facing interfaces

Each agent receives IDEA.md and research/SUMMARY.md as context. They return their analysis.

Synthesize all agent feedback into a design document. Present to the user section by section for approval:

- Architecture overview
- Component breakdown
- Interface/API design
- Data model (if applicable)
- UX flows (if applicable)
- Security considerations
- Accessibility plan (if applicable)
- Key trade-offs and decisions

After user approves all sections, write `.planning/DESIGN.md` and commit: `git commit "docs: system design approved"`

---

## Phase 4: Planning

Spawn the planning team:

- **`ideate:project-manager`** — Create detailed task breakdown with dependencies, acceptance criteria, and resumption points
- **`ideate:qa-engineer`** — Design test strategy covering unit, integration, and production-readiness tests
- **`ideate:devils-advocate`** — Stress-test the plan: are tasks too large? Missing edge cases? Unrealistic ordering?

Each agent receives IDEA.md, research/SUMMARY.md, and DESIGN.md.

The PM produces `.planning/PLAN.md`:

```markdown
# Implementation Plan

## Task Breakdown

### Wave 1 (no dependencies)
- [ ] Task 1.1: [description]
  - Acceptance: [testable criterion]
  - Files: [expected files to create/modify]
- [ ] Task 1.2: [description]
  ...

### Wave 2 (depends on Wave 1)
...

## Test Strategy
[QA engineer's test plan integrated into task waves]

## Resumption Points
[After each wave, state is consistent and work can be paused/resumed]

## Risk Register
[Devil's advocate findings, ranked by impact]
```

Present plan to user for approval. Commit: `git commit "docs: implementation plan approved"`

---

## Phase 5: Execution

Execute the plan in waves, spawning agents appropriate to each task:

### Per-Wave Process:

1. **Spawn `ideate:senior-engineer` agent(s)** — one per independent task in the wave. Each receives the full context (IDEA.md, DESIGN.md, PLAN.md) plus their specific task assignment.

2. **After wave completes, spawn reviewers:**
   - **`ideate:software-architect`** — Review implementation against design. Do components fit together? Are interfaces honored?
   - **`ideate:qa-engineer`** — Write and run tests for completed tasks. Report coverage.
   - **`ideate:security-researcher`** — Scan for vulnerabilities introduced (if applicable)
   - **`ideate:accessibility-engineer`** — Review for accessibility compliance (if applicable)

3. **`ideate:project-manager`** — Update PLAN.md progress, log deviations, ensure acceptance criteria are met

4. **Commit after each wave:** `git commit "feat: complete wave N — [summary]"`

5. **Proceed to next wave** or address issues found by reviewers

### After All Waves:

1. **`ideate:technical-writer`** — Document implementation decisions, API usage, architecture notes
2. **`ideate:qa-engineer`** — Final test pass, coverage report
3. **`ideate:devils-advocate`** — Final review: does the implementation match the original idea? Any drift?
4. **`ideate:project-manager`** — Final status report, requirement traceability (every requirement in IDEA.md maps to implemented code)

Write `.planning/COMPLETION.md` with final status. Commit: `git commit "docs: implementation complete"`

---

## Resumption Protocol

If work is interrupted at any phase, the artifacts on disk define the state:

| If you find... | Resume from... |
|----------------|---------------|
| Nothing in .planning/ | Phase 1: The Interrogation |
| IDEA.md only | Phase 2: Domain Research |
| IDEA.md + research/ | Phase 3: Design |
| IDEA.md + DESIGN.md | Phase 4: Planning |
| IDEA.md + DESIGN.md + PLAN.md | Phase 5: Execution (check PLAN.md for wave progress) |
| COMPLETION.md | Done |

When resuming, read all existing artifacts first, then continue from the appropriate phase. Summarize what's already been done before proceeding.

---

## Key Principles

- **The interrogation is the foundation.** A weak interrogation produces a weak design. Take the time.
- **Research prevents reinvention.** Always check before building from scratch.
- **The right team for the job.** Don't spawn a UX designer for a cron job.
- **Artifacts are the state.** Everything important is written to `.planning/`. If it's not in a file, it doesn't survive.
- **Challenge at every phase.** The devil's advocate reviews design AND plan AND implementation.
- **Atomic waves.** Each wave leaves the project in a consistent, testable state.
- **Document decisions, not just code.** Future maintainers need to know why, not just what.
