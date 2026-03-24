# rca

Perform thorough root cause analysis on bugs and regressions — find the REAL underlying cause, not just the symptom.

## What It Does

`/rca` takes a reported bug through five phases:

1. **Symptom Intake** — Deep questioning to understand the observed behavior, timeline, scope, and reproduction steps.
2. **Evidence Collection** — Parallel investigation of git history, architecture, code patterns, and test coverage.
3. **Hypothesis Formation** — Systematic 5 Whys and Fishbone analysis to generate multiple competing explanations.
4. **Root Cause Verification** — Rigorous verification with devil's advocate challenge and heuristic checks.
5. **Remediation Plan** — Fix design that addresses the root cause, with anti-pattern detection and regression prevention.

## Agent Team

| Role | When Active | Focus |
|------|------------|-------|
| Code Archaeologist | Phase 2 | Git history, blame, bisect, change correlation |
| Systems Analyst | Phase 2 | Architecture, dependencies, coupling, data flow |
| Evidence Collector | Phases 2, 4 | Code patterns, test coverage, error handling, environmental factors |
| Hypothesis Challenger | Phase 4 | Stress-testing proposed root causes, finding alternative explanations |
| Remediation Architect | Phase 5 | Fix design, anti-pattern detection, impact assessment |

## Philosophy

- **Treat the disease, not the symptom.** Every fix must address a structural issue.
- **Evidence before theory.** Gather facts before forming hypotheses.
- **Multiple hypotheses prevent tunnel vision.** Always generate at least 3 explanations.
- **Good root causes are structural.** "Someone made a mistake" is never a root cause.
- **Good fixes are simple.** If the fix is complex, you might be fixing the wrong thing.

## Usage

```
/rca Users are seeing 500 errors on the profile page after yesterday's deploy
/rca The test suite has been flaky for a week
/rca
```

## Artifacts

All state is written to `.planning/rca/`:

| Artifact | Phase | Contents |
|----------|-------|----------|
| `SYMPTOM.md` | 1 | Detailed symptom report with timeline and reproduction steps |
| `EVIDENCE.md` | 2 | Collected evidence from git history, architecture, and code analysis |
| `HYPOTHESES.md` | 3 | Ranked hypotheses with evidence assessment and falsification tests |
| `VERIFICATION.md` | 4 | Verified root cause with causal chain and heuristic checks |
| `PLAN.md` | 5 | Remediation plan with anti-pattern checks and regression prevention |

Work can be resumed from any phase based on which artifacts exist.
