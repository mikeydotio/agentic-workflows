---
name: design
description: Architecture design with cross-functional review driven by the team roster. Produces DESIGN.md. Spawns architect, devil's advocate, and conditional agents.
argument-hint: ""
---

# Design: Architecture with Cross-Functional Review

You are the design skill. Your job is to produce a thorough architecture design reviewed by a cross-functional agent team selected from the roster.

**Read inputs:**
- `.forge/IDEA.md` (required)
- `.forge/research/SUMMARY.md` (required)
- `.forge/TEAM.md` (required — drives agent selection)
- `.forge/handoffs/handoff-research.md` (if orchestrated — for context)

## Steps

### 1. Select Design Team

Read `.forge/TEAM.md` to determine which agents to spawn:

**Always spawn:**
- `software-architect` — Design system architecture, component boundaries, interfaces, data flow
- `devils-advocate` — Challenge the architect's design, find assumptions and risks

**Conditionally spawn (from TEAM.md):**
- `ux-designer` — If TEAM.md says YES for user-facing interfaces
- `security-researcher` — If TEAM.md says YES for sensitive data/auth/external input
- `accessibility-engineer` — If TEAM.md says YES for user-facing interfaces

### 2. Spawn Design Agents

Each agent receives `.forge/IDEA.md` and `.forge/research/SUMMARY.md` as context.

Spawn in two rounds:
1. **Round 1:** `software-architect` produces initial design + conditional agents (ux-designer, security-researcher, accessibility-engineer) review requirements
2. **Round 2:** `devils-advocate` reviews the architect's design + all conditional agent feedback

### 3. Synthesize Design Document

Combine all agent feedback into a cohesive design. Present each section as **plain text**, then use AskUserQuestion for approval:

Sections to cover:
- Architecture overview
- Component breakdown
- Interface/API design
- Data model (if applicable)
- UX flows (if applicable — from ux-designer)
- Security considerations (if applicable — from security-researcher)
- Accessibility plan (if applicable — from accessibility-engineer)
- Key trade-offs and decisions
- Devil's advocate findings and resolutions

For each section:
- **header:** "Approve?"
- **question:** "Does the [section name] look right?"
- **options:**
  - "Approved (Recommended)" / "This section is solid as-is. Pros: keeps design review moving. Cons: missed issues surface during planning."
  - "Needs changes" / "I see specific things to adjust. Pros: catches problems early when changes are cheap. Cons: adds a revision cycle."
  - "I have concerns" / "Something feels off but I need to articulate it. Pros: surfaces gut-level risks. Cons: may be hard to act on without specifics."

If "Needs changes" — ask what to change via AskUserQuestion, revise, re-present.

### 4. Write DESIGN.md

After all sections are approved, write `.forge/DESIGN.md`:

```markdown
# Architecture Design

## System Overview
[High-level description and text-based diagram]

## Components
### [Component Name]
- **Purpose:** [single sentence]
- **Interfaces:** [what it exposes]
- **Dependencies:** [what it consumes]
- **Key decisions:** [why this boundary, trade-offs]

## Data Flow
[How data moves through the system]

## Cross-Cutting Concerns
[Logging, error handling, configuration, etc.]

## Integration Points
[Where components connect, protocols, contracts]

## Security Considerations
[If applicable — threat model, trust boundaries]

## Accessibility Plan
[If applicable — WCAG targets, key accommodations]

## UX Flows
[If applicable — user interaction patterns]

## Design Decisions
| Decision | Rationale | Alternatives Considered |
|----------|-----------|------------------------|
| [decision] | [why] | [what else was evaluated] |
```

## Exit

**If `--orchestrated`:** Follow the Step Exit Protocol:
1. Write `.forge/DESIGN.md`
2. Write `.forge/handoffs/handoff-design.md` with:
   - Key Decisions: architecture overview, key trade-offs, per-section user approvals
   - Context for Next Step: component count and responsibilities, interface contracts, security/accessibility requirements, complexity areas, inter-component dependencies
   - Open Questions: implementation questions deferred to planning
3. Commit: `git add .forge/ && git commit -m "forge(design): architecture design approved"`
4. Queue freshen: `bash plugins/freshen/bin/freshen.sh queue "/forge plan --orchestrated" --source forge --summary "Design approved — architecture finalized"`
5. STOP

**If standalone:** Write `.forge/DESIGN.md`, report completion to user, exit.
