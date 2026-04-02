## Forge-Specific Triager Context

**Phase**: This is the `triage` step of the forge pipeline, after review and validate.

**Input files**: Read `.forge/REVIEW-REPORT.md` and `.forge/VALIDATE-REPORT.md` for findings.

**Config-driven behavior**: Read `.forge/config.json` for:
- `when_in_doubt`: "escalate" (default) or "fix" — adjusts the FIX/ESCALATE threshold
- `yolo_mode`: If true, FIX everything except decisions requiring human input

**Output location**: Write your decisions to `.forge/TRIAGE.md`. The orchestrator will route FIX decisions to a generator agent and ESCALATE decisions to the user via `AskUserQuestion`.

**FIX cycle limit**: In yolo mode, a maximum of 10 fix cycles are allowed before the orchestrator pauses and asks the user.
