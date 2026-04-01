# Auto-Resume

Freshen-based context clearing and re-invocation for autonomous execution.

## Mechanism

Pilot uses the freshen plugin for automatic session transitions. When pilot pauses (session limit reached, blocked, or any pause trigger), it queues a freshen signal. The sequence:

1. **Pause**: Pilot writes handoff, sets status to `paused`, releases lock
2. **Queue**: Pilot runs `bash plugins/freshen/bin/freshen.sh queue "/pilot resume" --source pilot`
3. **Stop**: Session ends. Freshen's Stop hook detects the signal, sends `/clear` via tmux
4. **Clear**: Context is wiped. Freshen's SessionStart(clear) hook reads the signal, sends `/pilot resume` via tmux
5. **Resume**: New session starts. Pilot's SessionStart hook injects state context. `/pilot resume` acquires lock and continues

This is fire-once: the signal file is consumed after use. Each pause must re-queue.

## tmux Requirement

Freshen requires tmux (`$TMUX` and `$TMUX_PANE` environment variables). Claude must be running inside a tmux session.

- **tmux available**: Auto-resume works automatically. No user intervention needed between sessions.
- **tmux not available**: Pilot logs a warning at `/pilot run` time. The user must run `/pilot resume` manually after each session ends. All other pilot functionality works normally.

## Setup (at `/pilot run`)

No installation step is needed. Pilot checks for tmux availability and reports:

```
If $TMUX and $TMUX_PANE are set:
  -> "Auto-resume via freshen is available."
Else:
  -> Warning: "tmux not detected -- auto-resume unavailable. Manual /pilot resume required."
```

## Pause (queuing the signal)

At every pause point in the execution loop:

```bash
bash plugins/freshen/bin/freshen.sh queue "/pilot resume" --source pilot
```

If the queue command fails (tmux not available, freshen not installed):
- Log: "Auto-resume unavailable. Run `/pilot resume` manually."
- Do NOT treat this as a fatal error -- pilot still pauses cleanly.

## Teardown

On `/pilot stop` or completion, cancel any pending signal:

```bash
bash plugins/freshen/bin/freshen.sh cancel --source pilot
```

## Session-Stop Hook

When the session ends unexpectedly (not a graceful `/pilot stop`), the pilot session-stop hook:
1. Writes a degraded handoff
2. Sets status to `paused`
3. Releases the lock
4. Attempts to queue a freshen signal for auto-resume:
   - Writes `.freshen/pilot.signal` directly (bypasses `freshen.sh` to avoid tmux validation in hook context)
   - If tmux is not available or the write fails, the signal is skipped -- user must `/pilot resume` manually

Note: There is a timing consideration with freshen's own Stop hook. If freshen's Stop hook runs before pilot's, it will not find a signal (because pilot hasn't written one yet). The signal then sits until the next session's startup clears it, or until the user manually resumes. This is acceptable degradation -- the graceful path (orchestrator queues freshen before session ends) covers the normal case.

## Safety

- Signal cancelled on `/pilot stop` (user-initiated graceful stop)
- Signal cancelled on completion (all stories done)
- Runaway safeguards (`max_sessions`, `max_total_retries`) prevent unbounded execution
- Freshen's cross-source conflict check prevents pilot's signal from conflicting with other sources
- Stale signal cleanup: freshen's Stop hook deletes signals older than 2 hours

## Resume Latency

With freshen, resume is near-instant:
- Session ends -> Stop hook fires `/clear` -> SessionStart hook sends `/pilot resume`
- Total latency: seconds (limited only by Claude's response time)

## Worst-Case Resume Latency

If a session crashes without releasing the lock, the next resume attempt must wait for the heartbeat to go stale (default: 30 minutes). With freshen, there is no additional trigger interval delay.
