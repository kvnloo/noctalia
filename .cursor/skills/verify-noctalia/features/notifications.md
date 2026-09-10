# Notifications

Native notification daemon (FreeDesktop) — toasts, DND, history, invoke/clear.

## Sub-features

- `toast-show` — `notification-show` summary / body / JSON payload
- `dnd` — `notification-dnd-set` / `toggle` / `status`
- `clear-active` — dismiss visible toasts (`notification-clear-active`)
- `clear-history` — wipe history (`notification-clear-history`)
- `invoke-latest` — default action on most recent active toast

## How to get to it (user POV)

- Apps emit via `org.freedesktop.Notifications`.
- Control-center notification history.
- IPC for agent-driven toasts and DND.

## Driving it with control-noctalia

Preconditions: Noctalia is the active notification daemon; doctor / IPC ok.

Staging IPC (`docs/user/ipc/media-and-ui.mdx`):

```bash
noctalia msg notification-show "Build finished"
noctalia msg notification-show "Build finished" "All tests passed"
noctalia msg notification-show '{"app_name":"Noctalia","summary":"Build finished","body":"All tests passed","urgency":"low","timeout_ms":4000,"icon":"circle-check"}'

noctalia msg notification-dnd-set on
noctalia msg notification-dnd-set off
noctalia msg notification-dnd-toggle
noctalia msg notification-dnd-status

noctalia msg notification-invoke-latest
noctalia msg notification-clear-active
noctalia msg notification-clear-history

# Thin harness
.cursor/skills/verify-noctalia/drive.sh notifications --test-notify
.cursor/skills/verify-noctalia/control-noctalia toggle-dnd
```

**Proof**: toast visible (or history entry under DND), DND status flip, clear-active empties toasts. Screenshot + IPC transcript.

## Gotchas

- There is **no** `notification-clear` verb — use `notification-clear-active` / `notification-clear-history`.
- DND suppresses toasts but history still fills; critical urgency may bypass depending on config.
- Competing daemons (mako/dunst) steal the D-Bus name — doctor should confirm Noctalia owns Notifications.
- JSON `notification-show` fields: `app_name`, `summary`, `body`, `urgency`, `timeout_ms`, `icon`, `category`, `desktop_entry`.
