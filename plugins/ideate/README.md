# ideate

> **DEPRECATED:** The ideate plugin has been merged into the unified **pilot** plugin. Use `/pilot` instead of `/ideate`. The pilot plugin includes all ideate functionality (interrogation, research, design, planning) plus autonomous execution, review, validation, triage, documentation, and deployment. Artifacts now live in `.pilot/` instead of `.planning/ideate/`.

Flesh out ideas through relentless questioning, then execute with a cross-functional agent team.

## What It Does

`/ideate` takes a raw idea through five phases:

1. **Interrogation** — Grills you to build deep understanding. Challenges assumptions, finds gaps, refuses vague answers.
2. **Domain Research** — Checks if the problem is already solved, identifies best practices and common pitfalls.
3. **Design** — Software architect designs the system, reviewed by devil's advocate, security, UX, and accessibility (as appropriate).
4. **Planning** — PM creates task breakdown, QA designs test strategy, devil's advocate stress-tests the plan.
5. **Execution** — Engineers implement in waves, with architecture review, testing, security scanning, and documentation after each wave.

## Agent Team

| Role | When Active | Focus |
|------|------------|-------|
| Domain Researcher | Phases 1-2 | Existing solutions, best practices, pitfalls |
| Software Architect | Phases 3, 5 | System design, component boundaries, integration review |
| Senior Engineer | Phase 5 | Implementation |
| QA Engineer | Phases 4-5 | Test strategy, test writing, coverage |
| UX Designer | Phases 3, 5 | Interaction flows, usability (UI projects only) |
| Project Manager | Phases 4-5 | Task tracking, progress, resumability |
| Devil's Advocate | Phases 3-5 | Assumption challenging, blind spot identification |
| Security Researcher | Phases 3, 5 | Vulnerability assessment, secure coding |
| Accessibility Engineer | Phases 3, 5 | WCAG compliance, inclusive design (UI projects only) |
| Technical Writer | Phase 5 | Documentation, architecture decision records |

## Usage

```
/ideate I want to build a CLI tool that...
/ideate
```

## Artifacts

All state is written to `.planning/`:
- `IDEA.md` — Validated idea with examined assumptions
- `research/` — Domain research findings
- `DESIGN.md` — Approved system design
- `PLAN.md` — Task breakdown with progress tracking
- `COMPLETION.md` — Final status report

Work can be resumed from any phase based on which artifacts exist.
