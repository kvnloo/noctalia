# Wallpaper

Per-monitor wallpaper surfaces plus picker panel and random/next/previous automation.

## Sub-features

- `wallpaper-get-set` — read/write default or per-connector path (`color:#RRGGBB` allowed)
- `wallpaper-cycle` — `wallpaper-next` / `wallpaper-previous` / `wallpaper-random` (± connector)
- `wallpaper-picker` — `panel-toggle wallpaper`

## How to get to it (user POV)

- Control center / wallpaper panel picker.
- Automation interval (random/slideshow) when enabled.
- IPC for deterministic agent control.

## Driving it with control-noctalia

Preconditions: doctor / IPC ok; at least one valid image path for set proofs.

Staging IPC (`docs/user/ipc/media-and-ui.mdx`):

```bash
noctalia msg wallpaper-get
noctalia msg wallpaper-get DP-1

noctalia msg wallpaper-set ~/Pictures/wall.png
noctalia msg wallpaper-set DP-1 ~/Pictures/wall.png
noctalia msg wallpaper-set 'color:#1a1b26'

noctalia msg wallpaper-next
noctalia msg wallpaper-previous
noctalia msg wallpaper-random
noctalia msg wallpaper-next DP-1
noctalia msg wallpaper-previous DP-1
noctalia msg wallpaper-random DP-1

noctalia msg panel-toggle wallpaper

# Thin harness (picker + cycle)
.cursor/skills/verify-noctalia/drive.sh wallpaper --list
.cursor/skills/verify-noctalia/drive.sh wallpaper --action=next
.cursor/skills/verify-noctalia/drive.sh wallpaper --action=previous
.cursor/skills/verify-noctalia/drive.sh wallpaper --action=random
.cursor/skills/verify-noctalia/drive.sh wallpaper --action=get
```

**Proof**: `wallpaper-get` before/after a `wallpaper-set` or cycle; optional screenshot of surface / picker.

## Gotchas

- Verb is `wallpaper-previous` — **not** `wallpaper-prev`.
- There is no `wallpaper-reload` in staging IPC.
- `wallpaper-set <connector> <path>` vs `wallpaper-set <path>` — connector is optional first token when it matches an output.
- Non-color paths must exist at call time; `~` is expanded.
- Picker is `panel-toggle wallpaper` (surfaces), not a dedicated wallpaper-* open verb.
