# sentry

Intelligent PreToolUse safety hook for Claude Code. Evaluates every tool call using a three-tier decision pipeline:

1. **Deterministic ALLOW** — 150+ known-safe readonly commands, plus deep subcommand analysis for git, gh, docker, kubectl, terraform, aws, gcloud, npm, and more
2. **Deterministic PASS with warning** — Known-destructive commands (`rm`, `sudo`, `kill`, `chmod`, etc.) surface clear `[sentry]` warnings
3. **AI Fallback** — Uncertain commands evaluated by Claude Sonnet via structured API call

## Permission Mode Awareness

Sentry auto-disables in **Bypass Permissions** mode and stays active in all other modes. Configurable per-mode via `/sentry enable|disable <mode>`.

| Mode | Default |
|------|---------|
| Normal (default) | Enabled |
| Plan Mode | Enabled |
| Accept Edits | Enabled |
| Bypass Permissions | Disabled |

## Configuration

Config at `~/.config/sentry/config.yaml` (auto-initialized on first run from bundled defaults).

| Setting | Default | Description |
|---------|---------|-------------|
| `disabled_modes` | `bypassPermissions` | Space-separated modes to disable in |
| `mode` | `standard` | `standard` / `strict` / `permissive` |
| `ai_enabled` | `true` | Claude API fallback for uncertain commands |
| `ai_model` | `claude-sonnet-4-6` | Model for AI evaluation |
| `ai_timeout` | `10` | API call timeout (seconds) |
| `custom_allow` | _(empty)_ | Space-separated commands to always allow |
| `custom_pass` | _(empty)_ | Space-separated commands to always pass |

## Management

Use `/sentry` to manage at runtime:

```
/sentry status                   Show config and mode status
/sentry enable <mode>            Enable in a permission mode
/sentry disable <mode>           Disable in a permission mode
/sentry mode strict              Change analysis mode
/sentry ai off                   Disable AI fallback
/sentry allow make               Always allow 'make'
/sentry block terraform          Always pass 'terraform' to user
/sentry test "curl -s ..."       Dry-run through the hook
/sentry reset                    Restore defaults
```

## AI Fallback

Set `ANTHROPIC_API_KEY` in your environment. When a command is uncertain, sentry calls Claude Sonnet with a structured prompt asking "Is this command potentially destructive?" and gets `{answer: boolean, rationale: string}` back. The rationale is always shown to the user.

## Requirements

- `jq` (JSON parsing)
- `curl` (AI fallback API calls)
- `ANTHROPIC_API_KEY` environment variable (for AI fallback; optional)
