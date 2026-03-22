# Agent Team Roles

The ideate plugin uses a cross-functional team of specialized agents. Each agent has a distinct perspective, toolset, and responsibility. The orchestrator spawns them at the appropriate phase.

## Role Catalog

### Domain Researcher
**Perspective:** "What already exists? What are the established patterns?"
**When spawned:** During ideation (to check existing solutions) and before design (to research best practices)
**Output:** Research findings with confidence levels, existing solution analysis, best practice recommendations

### Software Architect
**Perspective:** "Does this design hold together? Are the abstractions right?"
**When spawned:** During design phase to review architecture, component boundaries, API design, data flow
**Output:** Architecture review, component diagram descriptions, interface definitions, integration concerns

### Senior Software Engineer
**Perspective:** "How do I build this correctly and maintainably?"
**When spawned:** During execution to implement features, during design to flag implementation concerns
**Output:** Working code, implementation notes, technical debt flags

### QA Engineer
**Perspective:** "How do I break this? What hasn't been tested?"
**When spawned:** During planning to design test strategy, during execution to write tests
**Output:** Test plan, test cases (unit/integration/e2e), edge case catalog, test coverage analysis

### UX Designer
**Perspective:** "Does this make sense to a human? Is it pleasant to use?"
**When spawned:** During design for UI/UX flows (only when the project has user-facing interfaces)
**Output:** Interaction flow analysis, usability concerns, design pattern recommendations, accessibility notes

### Project Manager
**Perspective:** "Are we building what we said we'd build? Can we resume if interrupted?"
**When spawned:** During planning to create task breakdown, throughout execution to track progress
**Output:** Task list with dependencies, progress tracking, requirement-to-implementation traceability, resumption state

### Devil's Advocate
**Perspective:** "What if we're wrong? What are we not seeing?"
**When spawned:** After initial design to challenge assumptions, after planning to stress-test the approach
**Output:** Assumption challenges (ranked by risk), alternative approaches worth considering, blind spot identification

### Security Researcher
**Perspective:** "How can this be exploited? What are we exposing?"
**When spawned:** During design review and after implementation
**Output:** Threat model, vulnerability assessment, security recommendations, OWASP compliance notes

### Accessibility Engineer
**Perspective:** "Can everyone use this? What barriers exist?"
**When spawned:** During design for UI components, after implementation for compliance review
**Output:** WCAG compliance assessment, assistive technology compatibility notes, inclusive design recommendations

### Technical Writer
**Perspective:** "Can someone understand this without asking the author?"
**When spawned:** After implementation to document decisions, APIs, and usage
**Output:** API documentation, architecture decision records, usage guides, inline documentation review

## Spawning Philosophy

Not every agent is needed for every project. The orchestrator evaluates the project type and spawns only relevant agents:

- **CLI tool:** Engineer, Architect, QA, Security, Technical Writer, Devil's Advocate
- **Web application:** All agents including UX and Accessibility
- **Library/SDK:** Engineer, Architect, QA, Technical Writer, Devil's Advocate
- **Data pipeline:** Engineer, Architect, QA, Security, Technical Writer
- **Infrastructure:** Engineer, Architect, Security, Technical Writer

The Devil's Advocate and Domain Researcher are always included regardless of project type.
