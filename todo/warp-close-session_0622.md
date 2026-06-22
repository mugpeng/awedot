# Warp Window Close Leaves Session Tracked

## Bug

When a Claude session is running inside Warp, pressing `Ctrl-C` exits the session and awedot quickly removes it from the active/idle/success session list.

However, if the user directly closes the Warp window or tab that owns the session, the frontend session count does not decrease quickly. The session can remain visible in `idle`, `success`, or another non-completed state even though the terminal window is gone.

This behavior does not reproduce in Terminal.app, where closing or exiting the session is reflected correctly.

## Expected

Closing a Warp window/tab should be treated as the session ending. Within the normal process monitor interval, awedot should mark the session as `completed`, emit `sessions-updated`, and the frontend should stop displaying it.

## Notes

- The frontend already filters out sessions whose status is `completed`.
- The visible count remaining stale means the backend did not mark the session as completed or did not emit an update after doing so.
- Warp close can skip the normal `SessionEnd` hook path, so process/runtime fallback detection must handle it.
- Claude runtime discovery is a stronger signal here than PID existence: if the Claude runtime state file disappears from discovery, the session should be treated as dead.

## Suspected Cause

The process monitor was relying too heavily on PID liveness. For sessions that had a PID, it checked `kill(pid, 0)` and treated the session as alive if the PID still existed. When a Warp window is closed directly, the Claude runtime state can disappear and no `SessionEnd` hook may be delivered, but the old process/PID can briefly still look alive. That leaves the backend session in a non-`completed` state, so the frontend keeps tracking and displaying it.
