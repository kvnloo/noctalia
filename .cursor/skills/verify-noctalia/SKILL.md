# Noctalia Verification Skill

**Purpose**: Launch, verify, drive, and capture evidence from the Noctalia Wayland desktop shell.

**When to use**: Testing Noctalia changes (bars, notifications, wallpaper, control center, dock, launcher, lock screen), validating configuration, investigating UI/compositor integration bugs, or proving that a feature works end-to-end.

---

## Overview

Noctalia is a native Wayland desktop shell providing bars, panels, launcher, notifications, dock, lock screen, wallpaper, and control center. It runs atop Wayland compositors (Hyprland, Sway, Niri, etc.) and integrates via layer-shell, session-lock, and compositor-specific workspace backends.

This skill provides:
1. **Doctor** — pre-flight checks (dependencies, compositor, build, config)
2. **Launch** — start Noctalia in a controlled environment
3. **Drive** — execute IPC commands and feature scenarios
4. **Evidence** — capture screenshots, logs, state
5. **Cleanup** — tear down instances, temp files

---

## Prerequisites

### Runtime Requirements
- Wayland compositor running with `$WAYLAND_DISPLAY` set
- Hyprland, Sway, Niri, or compatible compositor supporting:
  - `zwlr-layer-shell-v1`
  - `ext-session-lock-v1` (for lock screen)
  - Workspace protocols (compositor-specific or `ext-workspace-v1`)

### Build Requirements (if not installed)
- Meson, GCC/Clang with C++23 support
- Dependencies per [BUILDING.md](../../../BUILDING.md)
- See `just configure && just build` for debug builds

### VM / Headless Limitations
**On cloud VMs without Wayland/X11**:
- `noctalia` binary will fail to start (needs compositor)
- Doctor can still validate:
  - Build success
  - Config parsing
  - IPC schema
  - CLI help/version
- Use **dry-run mode** for builds/config-only verification
- Ship the skill even if full runtime testing is INCONCLUSIVE

---

## Quick Start

### With Compositor (local/GUI environment)
```bash
cd /workspace
.cursor/skills/verify-noctalia/doctor.sh
.cursor/skills/verify-noctalia/launch.sh
.cursor/skills/verify-noctalia/drive.sh bar-toggle main
.cursor/skills/verify-noctalia/snapshot.sh test-bar-toggle
.cursor/skills/verify-noctalia/cleanup.sh
```

### Without Compositor (cloud VM)
```bash
cd /workspace
.cursor/skills/verify-noctalia/doctor.sh --dry-run
# INCONCLUSIVE: compositor not available, but build/config validated
```

---

## 1. Doctor — Pre-flight Checks

**Script**: `doctor.sh`

Validates environment, dependencies, build, and configuration.

### Usage
```bash
./doctor.sh [--dry-run] [--verbose]
```

### Checks
1. **Repository**: In `/workspace`, git status clean or WIP ok
2. **Build**: `build-debug/noctalia` exists or can be built via `just build`
3. **Dependencies**: Wayland libs, runtime deps (optional: `upower`, `ddcutil`)
4. **Compositor**: `$WAYLAND_DISPLAY` set, compositor process detected
5. **Configuration**: `example.toml` parses, no schema errors via `noctalia config validate`
6. **IPC**: Socket path available, schema check via `noctalia msg --help`
7. **Assets**: Runtime asset tree `assets/` exists with required files

### Exit Codes
- `0` — all checks passed
- `1` — critical failure (build, config invalid)
- `2` — warnings (compositor missing, optional deps missing) — can proceed with limitations

### Dry-Run Mode
On VMs without compositor:
```bash
./doctor.sh --dry-run
```
Skips compositor/runtime checks, validates build/config only.

---

## 2. Launch — Start Noctalia

**Script**: `launch.sh`

Spawns Noctalia in foreground or daemon mode, captures startup logs.

### Usage
```bash
./launch.sh [--daemon] [--log=path] [--config=path]
```

### Options
- `--daemon`: Background mode via `noctalia --daemon`
- `--log=path`: Redirect output to log file (default: `/tmp/noctalia-verify.log`)
- `--config=path`: Use custom config (default: `example.toml` or `~/.config/noctalia/config.toml`)

### Behavior
- Checks for existing instance via IPC socket
- Exports `NOCTALIA_VERIFY_PID` and `NOCTALIA_VERIFY_SOCKET`
- Waits for IPC socket readiness (up to 10s timeout)
- Returns when shell is responsive

### Example
```bash
./launch.sh --daemon --log=/tmp/noctalia-test.log
# Shell running, IPC socket at $NOCTALIA_VERIFY_SOCKET
```

---

## 3. Drive — Execute Feature Scenarios

**Script**: `drive.sh`

Orchestrates feature tests via IPC commands, validates responses.

### Usage
```bash
./drive.sh <feature> [options]
```

### Supported Features
See `features/` directory for detailed scenarios:
- `bar` — toggle, show, hide bars
- `control-center` — open/close control center
- `notifications` — show test notifications, check history
- `wallpaper` — list, set wallpapers
- `launcher` — open, search, close launcher
- `dock` — pin/unpin apps, toggle visibility

### Example
```bash
./drive.sh bar --action=toggle --id=main
./drive.sh notifications --test-notify
./drive.sh wallpaper --list
```

### IPC Commands
Wraps `noctalia msg <command>` with validation:
```bash
noctalia msg bar-toggle main
noctalia msg panel-open launcher
noctalia msg notification-show "Test" "Body text"
```

### Feature Files
Each `features/<feature>.md` documents:
- **Goal**: What the feature does
- **Commands**: IPC commands to exercise it
- **Expected**: Observable outcomes (panel visible, notification toast, etc.)
- **Evidence**: Screenshot/log artifacts to capture

---

## 4. Evidence — Capture Artifacts

**Script**: `snapshot.sh`

Captures screenshots, logs, configuration state for proof artifacts.

### Usage
```bash
./snapshot.sh <name> [--type=screenshot|log|state|all]
```

### Artifact Types
- `screenshot`: Fullscreen capture via compositor or `grim`
- `log`: Noctalia output, IPC responses, system logs
- `state`: Config, IPC handler list, running panels/bars
- `all`: Everything above

### Output Location
```
/tmp/noctalia-evidence/<timestamp>-<name>/
  screenshot.png
  noctalia.log
  ipc-state.txt
  config-dump.toml
```

### Example
```bash
./snapshot.sh test-bar-toggle --type=screenshot
# Saved to /tmp/noctalia-evidence/20260909-2319-test-bar-toggle/screenshot.png
```

### Integration
Evidence artifacts survive cleanup — copy to workspace for commit:
```bash
cp -r /tmp/noctalia-evidence /workspace/verification-artifacts/
git add verification-artifacts/
```

---

## 5. Cleanup — Tear Down

**Script**: `cleanup.sh`

Stops Noctalia instance, removes temp files, restores environment.

### Usage
```bash
./cleanup.sh [--keep-logs] [--keep-evidence]
```

### Actions
1. Send `quit` via IPC if socket available
2. Fallback to `kill $NOCTALIA_VERIFY_PID`
3. Remove IPC socket, lockfiles
4. Delete temp logs (unless `--keep-logs`)
5. Preserve evidence artifacts (default: keep)

### Example
```bash
./cleanup.sh
# Noctalia stopped, logs removed, evidence preserved in /tmp/noctalia-evidence/
```

---

## Feature Test Scenarios

See `features/` for detailed test plans:
- **[features/bar.md](features/bar.md)** — Bar visibility, widgets, multi-monitor
- **[features/control-center.md](features/control-center.md)** — Settings, quick actions, network/bluetooth
- **[features/notifications.md](features/notifications.md)** — Toasts, history, urgency levels
- **[features/wallpaper.md](features/wallpaper.md)** — Wallpaper picker, multi-monitor, automation
- **[features/launcher.md](features/launcher.md)** — App search, calculator, emoji picker

Each feature file includes:
- **Commands** to drive the feature
- **Expected behavior** (UI changes, panel states)
- **Evidence** (what to capture as proof)

---

## Helpers — Utility Scripts

### `ipc-send.sh` — Safe IPC Wrapper
```bash
./ipc-send.sh <command> [args...]
# Wraps noctalia msg, validates socket, captures response
```

### `wait-for-socket.sh` — IPC Ready Check
```bash
./wait-for-socket.sh [timeout_seconds]
# Polls for IPC socket, returns when ready or timeout
```

### `screenshot.sh` — Capture Display
```bash
./screenshot.sh <output_path>
# Uses grim, compositor screencopy, or fallback
```

### `check-panel.sh` — Panel State Query
```bash
./check-panel.sh <panel_name>
# Returns 0 if panel is open, 1 if closed
```

---

## Proving Once — Example Workflow

### Goal
Prove bar toggle works: bar visible → hidden → visible.

### Steps
```bash
# 1. Doctor
./doctor.sh || exit 1

# 2. Launch
./launch.sh --daemon --log=/tmp/noctalia-bar-test.log

# 3. Capture initial state
./snapshot.sh bar-initial --type=screenshot

# 4. Toggle off
./drive.sh bar --action=toggle --id=main
sleep 0.5
./snapshot.sh bar-hidden --type=screenshot

# 5. Toggle on
./drive.sh bar --action=toggle --id=main
sleep 0.5
./snapshot.sh bar-visible --type=screenshot

# 6. Cleanup
./cleanup.sh --keep-evidence

# 7. Evidence
ls /tmp/noctalia-evidence/*/screenshot.png
# bar-initial, bar-hidden, bar-visible — PASS if bar disappears then reappears
```

### Fail→Pass Pattern
To show a fix working:
1. Reproduce bug on `main` branch: capture evidence → `evidence-before/`
2. Apply fix on feature branch
3. Re-run scenario: capture evidence → `evidence-after/`
4. Commit both: shows broken → fixed transition

---

## Cloud VM / Headless Workflow

When compositor is unavailable:

### Doctor Only
```bash
./doctor.sh --dry-run
# Exit code 2 (warnings): compositor unavailable
# Still validates: build, config, CLI, IPC schema
```

### Report INCONCLUSIVE
```bash
echo "INCONCLUSIVE: Noctalia verification skill created, but full runtime testing blocked."
echo "Blocker: No Wayland compositor available on cloud VM."
echo "Validated: build success, config parsing, IPC schema."
echo "Evidence: /workspace/.cursor/skills/verify-noctalia/ (skill ready for local testing)"
```

Ship the skill anyway — it's useful for local dev, CI with compositor, or future VM with Wayland.

---

## Integration with CI

### GitHub Actions Example
```yaml
- name: Install Wayland Test Compositor
  run: |
    sudo apt-get install -y weston xvfb-run
    
- name: Verify Noctalia
  run: |
    xvfb-run weston --backend=headless-backend.so &
    export WAYLAND_DISPLAY=wayland-0
    .cursor/skills/verify-noctalia/doctor.sh
    .cursor/skills/verify-noctalia/launch.sh --daemon
    .cursor/skills/verify-noctalia/drive.sh bar --smoke-test
    .cursor/skills/verify-noctalia/cleanup.sh
```

---

## Troubleshooting

### "Compositor not found"
- Ensure `$WAYLAND_DISPLAY` is set
- Check compositor is running: `ps aux | grep -E "hyprland|sway|niri"`
- On cloud VM: use `--dry-run` mode

### "IPC socket timeout"
- Shell failed to start: check logs in `/tmp/noctalia-verify.log`
- Compositor incompatible: Noctalia needs layer-shell support
- Check dependencies: `./doctor.sh --verbose`

### "Build failed"
- Missing deps: see [BUILDING.md](../../../BUILDING.md)
- C++ version: needs GCC 13+ or Clang 16+ for C++23
- Run `just configure && just build` manually

### "Screenshot failed"
- Install `grim` for Wayland screenshots
- Or use compositor's native capture (Hyprland: `hyprctl screenshot`)
- Fallback: log-based verification only

---

## Extending the Skill

### Adding New Features
1. Create `features/new-feature.md`
2. Document commands, expected behavior, evidence
3. Update `drive.sh` to support `./drive.sh new-feature`
4. Add to `features/README.md` index

### Custom IPC Commands
Wrap new commands in `ipc-send.sh`:
```bash
./ipc-send.sh workspace-switch 2
./ipc-send.sh theme-apply my-theme.toml
```

### Automated Test Suites
Chain drive scenarios:
```bash
for feature in bar notifications wallpaper; do
  ./drive.sh $feature --smoke-test || exit 1
done
```

---

## References

- [Noctalia README](../../../README.md) — Project overview
- [BUILDING.md](../../../BUILDING.md) — Build dependencies and instructions
- [CONTRIBUTING.md](../../../CONTRIBUTING.md) — Architecture, debugging, code style
- [example.toml](../../../example.toml) — Full configuration reference
- [IPC Schema](../../../src/ipc/) — `noctalia msg --help` for command list

---

## License

Same as Noctalia (MIT). This skill is part of the Noctalia repository tooling.

---

**Build the Lever**: This skill is verification-as-infrastructure. Doctor catches environment issues. Drive automates manual testing. Evidence makes proof portable. Cleanup keeps runs isolated. Together: tight iteration loops, reproducible failures, confident deploys.
