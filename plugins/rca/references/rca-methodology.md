# RCA Methodology Reference

Proven root cause analysis techniques for software bugs.

## 5 Whys

Iterative "Why?" questioning to trace from symptom to root cause.

### How It Works
1. State the symptom
2. Ask "Why does this happen?"
3. Answer with a factual cause (not speculation)
4. Ask "Why?" again on the answer
5. Repeat until you reach a cause that is ACTIONABLE and STRUCTURAL

### Rules
- Each answer must be supported by evidence (code, logs, history)
- If an answer has multiple possible causes, BRANCH the chain
- Stop when the cause is something you can FIX STRUCTURALLY, not just defensively
- "Human error" is never a root cause — ask what allowed the error to happen

### Example
1. Symptom: API returns 500 error
2. Why? — Handler throws NullPointerException
3. Why? — `user.profile` is null
4. Why? — New users don't have a profile created automatically
5. Why? — Profile creation was split into a separate service but no contract enforces creation
6. Root cause: Missing invariant — no enforcement that a user always has a profile

### Anti-patterns
- Stopping too early ("because someone made a mistake")
- Circular reasoning ("A causes B because B causes A")
- Speculation without evidence ("it's probably a race condition")
- Accepting "it's always been that way" as an answer

## Fishbone / Ishikawa Diagram

Categorize potential causes to ensure comprehensive coverage.

### Software-Adapted Categories

| Category | What to Look For |
|----------|-----------------|
| **Code** | Logic errors, type mismatches, off-by-one, null handling, race conditions, resource leaks |
| **Architecture** | Missing abstractions, leaky boundaries, implicit coupling, shared mutable state, circular dependencies |
| **Dependencies** | Version changes, API contract violations, transitive dependency conflicts, deprecated APIs |
| **Environment** | Config differences between environments, resource limits, DNS/networking, timezone/locale |
| **Process** | Missing tests, insufficient code review, unclear ownership, missing documentation |
| **Data** | Unexpected inputs, schema changes, encoding issues, data migration artifacts, stale caches |

### When to Use
- When the 5 Whys branches extensively (many possible causes)
- When the bug could have multiple contributing factors
- As a completeness check — have we considered all categories?

## Fault Tree Analysis

Hierarchical decomposition with AND/OR logic.

### How It Works
- Top event: The observed bug
- Branch with OR: "This bug occurs if A happens OR B happens"
- Branch with AND: "This bug occurs if C happens AND D happens"
- Continue decomposing until you reach basic events (atomic causes)

### When to Use
- Complex bugs with multiple contributing factors
- Intermittent bugs where multiple conditions must align
- When you need to understand COMBINATIONS of causes

## Kepner-Tregoe Change Analysis

Correlate changes with bug appearance.

### The Key Questions
1. **WHAT** is affected vs what is NOT affected?
2. **WHERE** does it occur vs where does it NOT occur?
3. **WHEN** does it occur vs when does it NOT occur?
4. **WHAT CHANGED** in the timeframe between "working" and "broken"?

### The Distinction Matrix

| Dimension | IS (affected) | IS NOT (unaffected) | What's Different? | What Changed? |
|-----------|--------------|--------------------|--------------------|--------------|
| What | | | | |
| Where | | | | |
| When | | | | |

### When to Use
- Clear regressions (something that used to work stopped working)
- Environment-specific bugs (works in staging, fails in production)
- User-specific bugs (affects some users but not others)
