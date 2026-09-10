# Noctalia Feature Test Scenarios

This directory is the maintained source for verifying user-facing Noctalia behavior. Read the index before driving the shell, then use the matching feature file.

## Feature Index

1. **[bar.md](bar.md)** — Bar visibility, reserve space, auto-hide, layer
2. **[control-center.md](control-center.md)** — Control center panel + tabs
3. **[notifications.md](notifications.md)** — Toasts, DND, history, clear/invoke
4. **[wallpaper.md](wallpaper.md)** — Wallpaper get/set/next/previous/random + picker
5. **[launcher.md](launcher.md)** — Launcher search, app launch, calculator, emoji picker
6. **[theme-mode-toggle.md](theme-mode-toggle.md)** — Dark ↔ light theme mode via IPC

## How to Use

Each feature file uses the four-H2 template:

1. **Sub-features** — named slices to prove
2. **How to get to it (user POV)** — UI / IPC entry points
3. **Driving it with control-noctalia** — literal recipes + evidence
4. **Gotchas** — staging IPC truth, restore hazards, timing

### Running a Feature Test

```bash
# From repository root
.cursor/skills/verify-noctalia/launch.sh --daemon
.cursor/skills/verify-noctalia/drive.sh <feature-name>
.cursor/skills/verify-noctalia/snapshot.sh <feature-name>
.cursor/skills/verify-noctalia/cleanup.sh

# Or the preferred harness
.cursor/skills/verify-noctalia/control-noctalia doctor
.cursor/skills/verify-noctalia/control-noctalia feature theme-mode-toggle
```

## Adding New Features

1. Create `new-feature.md` in this directory
2. Use only the four H2s above (no Description/Configuration/Test Scenarios sprawl)
3. Align IPC verbs to staging docs under `docs/user/ipc/`
4. Update this README index
5. Add a thin driver in `drive.sh` / `control-noctalia` when useful
