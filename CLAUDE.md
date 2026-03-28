# Handy Plugins Marketplace

This repo is a Claude Code plugin marketplace owned by mikeydotio.

## Structure

- `.claude-plugin/marketplace.json` — marketplace manifest listing all plugins
- `plugins/<name>/` — individual plugin directories

## Plugin Anatomy

Each plugin under `plugins/` follows this structure:

```
plugins/my-plugin/
├── .claude-plugin/
│   └── plugin.json          # Required: { "name", "description" }
├── skills/                  # Skills (preferred format)
│   └── skill-name/
│       └── SKILL.md         # YAML frontmatter + markdown instructions
├── commands/                # Legacy command format
│   └── command-name.md
├── .mcp.json                # Optional: MCP server config
└── README.md                # Optional: documentation
```

## When Adding a New Plugin

1. Create the plugin directory under `plugins/`
2. Add `.claude-plugin/plugin.json` with at minimum `name` and `description`
3. Add the plugin to `.claude-plugin/marketplace.json` in the `plugins` array:
   ```json
   {
     "name": "my-plugin",
     "description": "What it does",
     "source": "./plugins/my-plugin"
   }
   ```
4. Skills use `skills/<name>/SKILL.md` format with YAML frontmatter (`name`, `description` required)

<!-- semver:start -->
## Semantic Versioning

This project uses semantic versioning managed by the `/semver` plugin.

### Version Awareness
- Read the `VERSION` file at the start of each conversation to know the current version.
- Read `.semver/config.yaml` to understand the versioning configuration.
- When discussing releases, deployments, or changes, reference the current version.

### Commit Discipline
- Write meaningful, descriptive commit messages. Each commit message may appear in an auto-generated changelog.
- Use conventional-commit-style prefixes when they fit naturally: `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`.
- The first line of the commit message should be a concise summary (under 72 characters). Add detail in the body if needed.

### Version Bump Guidance
When recommending or performing a version bump:
- **patch** (0.0.x): Bug fixes, documentation corrections, minor refactors with no behavior change.
- **minor** (0.x.0): New features, new capabilities, non-breaking additions to the public API or user-facing behavior.
- **major** (x.0.0): Breaking changes — removed features, changed interfaces, incompatible API modifications, behavior changes that require consumers to update.

When you notice the user has completed a logical unit of work, suggest running `/semver bump` with the appropriate level.

### Hooks
- Custom pre-bump and post-bump hooks can be added in `.semver/hooks/`.
- Never trigger `/semver bump` from within a hook — this causes infinite recursion.

### Configuration
Versioning settings are in `.semver/config.yaml`. Do not modify this file unless the user explicitly asks to change semver settings.
<!-- semver:end -->
