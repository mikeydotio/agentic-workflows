# Session Locking

Heartbeat-based lock protocol to prevent duplicate work when remote triggers fire while a session is active.

## Lock File

`.pilot/lock.json` (gitignored — ephemeral runtime artifact)

```json
{
  "holder": "session-abc123",
  "acquired_at": "2026-03-28T14:30:00Z",
  "heartbeat_at": "2026-03-28T14:35:00Z"
}
```

## Protocol

### Acquiring a Lock

1. Check if `.pilot/lock.json` exists
2. If no lock → create it with current session ID and timestamp → acquired
3. If lock exists → check heartbeat staleness

### Heartbeat Staleness Check

```
age = now - lock.heartbeat_at
stale = age > heartbeat_window_minutes (from config.json, default 30)
```

- **Heartbeat fresh** (age < window) → Lock is held by an active session
  - Exit with message: "Work is already running in another session"
- **Heartbeat stale** (age >= window) → Previous session likely crashed
  - Break the lock (delete and recreate)
  - Log warning: "Broke stale lock (holder: [old holder], last heartbeat: [timestamp])"
  - Acquire new lock

### Updating Heartbeat

Update `heartbeat_at` in lock.json at these points:
1. **Before spawning generator** — reflects active work starting
2. **After generator completes, before spawning evaluator** — work transitioning
3. **After each loop iteration** — general health signal

This ensures the heartbeat reflects active work, not just loop overhead.

### Releasing a Lock

Delete `.pilot/lock.json`. Triggered by:
- `/pilot stop` (graceful user stop)
- Session stop hook
- Completion sequence

### No PID Checks

The protocol uses heartbeat-only — no PID checks. PID-based locking is fragile in containers where process namespaces differ between sessions.

## Heartbeat Window Tuning

Default: 30 minutes (`heartbeat_window_minutes` in config.json).

The window should exceed the expected maximum duration of a single story (generator + checks + evaluator):
- **Too short**: False stale-lock detection → duplicate work
- **Too long**: Delayed crash recovery

**Worst-case resume latency**: heartbeat window only = ~30 minutes (default). Freshen fires immediately when the session ends, so there is no trigger interval component. The heartbeat window only matters for crash recovery (stale lock detection).

## Edge Cases

### Concurrent Resume Attempts
Freshen is fire-once per pause, so concurrent triggers are not a concern under normal operation. If a user manually runs `/pilot resume` while a freshen-triggered resume is starting, the lock check prevents duplicate work: the second attempt sees a fresh heartbeat and exits.

### Session Crash Without Lock Release
The session-stop hook attempts to queue a freshen signal for auto-resume. If the signal was queued successfully, the next session starts automatically. If not (hook failed to run, tmux unavailable), the user must manually run `/pilot resume`. The recovery sequence handles in-progress/verifying stories (resets to todo).
