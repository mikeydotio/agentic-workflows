---
name: deploy
description: Deployment step. Never proceeds without explicit user permission via DEPLOY-APPROVAL.md. Produces COMPLETION.md.
argument-hint: ""
---

# Deploy: Ship It

You are the deploy skill. Your job is to deploy the project according to its deployment needs. **You never run without explicit user permission** — the orchestrator writes `DEPLOY-APPROVAL.md` only after the user approves.

**Read inputs:**
- `.pilot/DEPLOY-APPROVAL.md` (required — must exist before deploy runs)
- `.pilot/DOCUMENTATION.md` (for deployment docs)
- `.pilot/DESIGN.md` (for infrastructure context)
- `.pilot/IDEA.md` (for deployment requirements)
- `.pilot/handoffs/handoff-document.md` (for context)

## Safety Gate

**CRITICAL:** If `.pilot/DEPLOY-APPROVAL.md` does not exist, do NOT proceed. Exit with:
"Deploy requires explicit approval. Run `/pilot continue` after the post-document pause to approve deployment."

## Steps

### 1. Assess Deployment Needs

Read IDEA.md and DESIGN.md to determine what deployment means for this project:

- **Web application**: Deploy to hosting platform (Vercel, Railway, AWS, etc.)
- **CLI tool**: Publish to package registry (npm, PyPI, crates.io)
- **Library**: Publish package, update docs
- **Infrastructure**: Apply terraform/CDK/ansible changes
- **Internal tool**: Copy to target location, restart services
- **No deployment needed**: Some projects just need to be built and tested

### 2. Present Deployment Plan

Use AskUserQuestion to confirm the deployment approach:
- **header:** "Deploy Plan"
- **question:** "Here's what I'll do to deploy: [plan]. Proceed?"
- **options:** ["Go ahead", "Adjust the plan", "Cancel deployment"]

If "Cancel" → write COMPLETION.md without deployment, mark as complete.

### 3. Execute Deployment

Follow the deployment plan. Be conservative:
- Run pre-deployment checks (tests, build, lint)
- Execute deployment steps
- Verify deployment succeeded (health checks, smoke tests)
- Report results

### 4. Write COMPLETION.md

Write `.pilot/COMPLETION.md`:

```markdown
# Pipeline Complete

## Timestamp
[ISO 8601]

## Project
[Project name from IDEA.md]

## Pipeline Summary
- Steps completed: [list]
- Fix cycles: [count]
- ESCALATE stories resolved: [count]
- Deployment: [deployed to X / not deployed / skipped]

## What Was Built
[Brief description of what the project does]

## Key Metrics
- Stories completed: [count]
- Tests: [pass/fail/total]
- Documentation: [files created]

## Deviations from Original Idea
[Any significant changes from IDEA.md requirements]

## Known Issues
[ESCALATE items that were resolved, any remaining concerns]

## Post-Deployment Notes
[Any manual steps, monitoring to set up, follow-up tasks]
```

## Exit

**If `--orchestrated`:**
1. Write `.pilot/COMPLETION.md`
2. Cancel freshen signal: `bash plugins/freshen/bin/freshen.sh cancel --source pilot`
3. Commit: `git add .pilot/ && git commit -m "pilot(deploy): pipeline complete"`
4. Report completion to user — this is the end of the pipeline

**If standalone:** Same as orchestrated — deploy is always the final step.
