# Control Center

Quick-settings panel (network, bluetooth, audio, media, calendar, shell prefs).

## Sub-features

- `cc-open-close` — open / close / toggle the control-center panel
- `cc-tab` — open a specific tab via optional context (`media`, `audio`, …)
- `cc-with-context` — `panel-open` / `panel-toggle` context passthrough

## How to get to it (user POV)

- Bar control-center widget click.
- Keyboard shortcut if configured.
- IPC: `panel-toggle control-center` (preferred for agents).

## Driving it with control-noctalia

Preconditions: doctor PASS / IPC responsive.

Staging IPC (`docs/user/ipc/surfaces.mdx`):

```bash
noctalia msg panel-open control-center
noctalia msg panel-close control-center
noctalia msg panel-toggle control-center
noctalia msg panel-toggle control-center media
noctalia msg panel-toggle control-center audio

# Harness wrappers
.cursor/skills/verify-noctalia/control-noctalia open-panel control-center
.cursor/skills/verify-noctalia/control-noctalia open-panel control-center audio
.cursor/skills/verify-noctalia/drive.sh control-center --action=toggle
.cursor/skills/verify-noctalia/drive.sh control-center --action=open
.cursor/skills/verify-noctalia/drive.sh control-center --action=close
```

**Proof**: screenshot of open panel (and optional tab), then close. Capture IPC stdout/stderr.

## Gotchas

- Prefer `panel-toggle control-center [tab]` over invented `control-center-*` verbs.
- `panel-close` without id closes the active panel; with id closes that panel if active.
- `panel-open` does not toggle closed when already open — use it when you need a guaranteed open.
- Tab context names follow Control Center tabs in the running build; unknown tabs may no-op.
