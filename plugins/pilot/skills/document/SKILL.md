---
name: document
description: Comprehensive project documentation. Works even with ESCALATE stories pending. Spawns technical-writer agent. Produces DOCUMENTATION.md.
argument-hint: ""
---

# Document: Project Documentation

You are the document skill. Your job is to produce comprehensive project documentation covering architecture decisions, API usage, setup guides, and implementation notes. This step runs regardless of whether ESCALATE stories are pending — documentation is always valuable.

**Read inputs:**
- `.pilot/IDEA.md` (required — original requirements)
- `.pilot/DESIGN.md` (required — architecture)
- `.pilot/PLAN.md` (for implementation context)
- `.pilot/REVIEW-REPORT.md` (for quality findings)
- `.pilot/VALIDATE-REPORT.md` (for test coverage)
- `.pilot/TRIAGE.md` (for known issues)
- `.pilot/handoffs/handoff-triage.md` (for context)

## Steps

### 1. Spawn Documentation Agent

Spawn `technical-writer` agent with all planning artifacts and the implemented codebase as context.

The technical writer:
- Reads the entire codebase
- Cross-references with IDEA.md requirements and DESIGN.md architecture
- Documents how to use, understand, and change the project
- Records architecture decision records (ADRs) for key design choices
- Notes known issues from TRIAGE.md (both FIX'd and ESCALATE'd items)

### 2. Review Documentation

Present documentation sections to the user as **plain text**. For key sections, use AskUserQuestion:

- **header:** "Docs OK?"
- **question:** "Does this documentation capture everything important?"
- **options:** ["Looks good", "Missing something", "Needs revision"]

If changes needed, revise and re-present.

### 3. Write Documentation

Write `.pilot/DOCUMENTATION.md`:

```markdown
# Project Documentation

## Overview
[What this project does and why — from IDEA.md]

## Getting Started
[Setup instructions, prerequisites, first run]

## Architecture
[System overview from DESIGN.md, component diagram, data flow]

## API / Interface Reference
[Public interfaces, their contracts, usage examples]

## Configuration
[All configuration options and their effects]

## Development
[How to develop, test, and contribute]

## Architecture Decision Records
### ADR-001: [Decision Title]
- **Context**: [why this decision was needed]
- **Decision**: [what was decided]
- **Alternatives**: [what was considered]
- **Consequences**: [trade-offs]

## Known Issues
[From TRIAGE.md — FIX'd issues and their resolutions, pending ESCALATE items]

## Test Coverage
[Summary from VALIDATE-REPORT.md]
```

The technical writer may also create or update other documentation files (README.md, API docs, etc.) as appropriate for the project.

## Exit

**If `--orchestrated`:** Follow the Step Exit Protocol:
1. Write `.pilot/DOCUMENTATION.md` (and any other doc files)
2. Write `.pilot/handoffs/handoff-document.md` with:
   - Key Decisions: documentation scope, files created
   - Context for Next Step: pipeline summary, ESCALATE status
   - Pipeline State: ESCALATE stories pending count
3. Commit: `git add .pilot/ && git commit -m "pilot(document): project documentation"`
4. Queue freshen: `bash plugins/freshen/bin/freshen.sh queue "/pilot continue" --source pilot`
5. STOP

The orchestrator enters the **post-document pause** on next `continue` — it ALWAYS pauses here for user review, never auto-advances to deploy.

**If standalone:** Write documentation, report to user, exit.
