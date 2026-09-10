# Bar

Multi-monitor Wayland layer-shell bars with widgets (workspaces, clock, tray, etc.).

## Sub-features

- `bar-visibility` — show / hide / toggle matching bar instance(s)
- `bar-reserve` — toggle exclusive reserve space
- `bar-auto-hide` — temporary on / off / smart auto-hide
- `bar-layer` — temporary `top` vs `overlay` layer-shell layer

## How to get to it (user POV)

- Bars appear on launch when configured under bar settings.
- Edge hover / gesture may reveal an auto-hidden bar.
- IPC is the reliable agent path (no click coordinates).

## Driving it with control-noctalia

Preconditions: `control-noctalia doctor` (or compositor + `noctalia msg status`).

Staging IPC (`docs/user/ipc/surfaces.mdx`):

```bash
# Omit both args → every bar on every output
noctalia msg bar-show
noctalia msg bar-hide
noctalia msg bar-toggle

# Named bar + optional monitor selector
noctalia msg bar-toggle default
noctalia msg bar-show default DP-1
noctalia msg bar-hide default

noctalia msg bar-reserve-toggle
noctalia msg bar-auto-hide-set on
noctalia msg bar-auto-hide-set off
noctalia msg bar-auto-hide-set smart
noctalia msg bar-layer-set top
noctalia msg bar-layer-set overlay
```

Thin harness:

```bash
.cursor/skills/verify-noctalia/drive.sh bar --action=toggle
.cursor/skills/verify-noctalia/drive.sh bar --action=show
.cursor/skills/verify-noctalia/drive.sh bar --action=hide
```

**Proof**: before/after screenshots or `noctalia msg status` with no IPC error. Prefer toggle → show so the session ends visible.

## Gotchas

- `bar-hide` blocks edge/pointer reveal until the next show/toggle; `bar-toggle` does not.
- Args are `[bar-name] [monitor-selector]` — not a required positional `main` id. Empty args are valid.
- There is no `reload-config` bar verb in staging IPC; do not invent one in recipes.
- Overlay layer shows the bar above fullscreen apps; attached panels follow the bar layer.
