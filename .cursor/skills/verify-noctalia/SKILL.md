---
name: verify-noctalia
description: Launch, doctor, drive, and capture evidence for Noctalia Wayland shell features (bar, panels, notifications, wallpaper, theme-mode). Use when proving Noctalia behavior live or aligning skill IPC to staging.
---

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
cd /workspace/.cursor/skills/verify-noctalia
./control-noctalia doctor
./control-noctalia feature theme-mode-toggle

# Or via CLI (after build)
noctalia verify doctor
noctalia verify feature theme-mode-toggle
```

### Without Compositor (cloud VM)
```bash
cd /workspace/.cursor/skills/verify-noctalia
./control-noctalia doctor
# Exit 2 INCONCLUSIVE: compositor not available
```

---

## 1. Doctor — Pre-flight Checks

**Script**: `control-noctalia doctor`

Validates compositor, Noctalia process, IPC, and theme tools.

### Usage
```bash
./control-noctalia doctor [--verbose]

# Or via CLI
noctalia verify doctor [--verbose]
```

### Checks
1. **Compositor**: Detects Hyprland, Sway, or Niri via environment variables
2. **Noctalia Process**: Checks if `noctalia` is running
3. **IPC Socket**: Verifies socket exists at `$XDG_RUNTIME_DIR/noctalia.sock`
4. **IPC Responsiveness**: Tests `noctalia msg status` command
5. **Theme Tools**: Notes `gsettings`/`dconf` if present (optional; theme feature PASS is IPC-only)
6. **Portal Tools**: Checks for `busctl` for D-Bus monitoring

### Exit Codes
- `0` (PASS) — Compositor present, Noctalia responding
- `1` (FAIL) — Critical error executing doctor
- `2` (INCONCLUSIVE) — No compositor detected or Noctalia not responding

### Without Compositor
On VMs without compositor, doctor returns exit code 2:
```bash
./control-noctalia doctor
# STATUS: INCONCLUSIVE (no compositor detected)
# Verification requires Hyprland, Sway, or Niri compositor.
```

---

## 2. Feature Testing

**Script**: `control-noctalia feature <feature-name>`

Executes automated feature verification tests.

### Usage
```bash
./control-noctalia feature <feature-name> [--evidence-dir DIR] [--no-cleanup]

# Or via CLI
noctalia verify feature <feature-name> [--evidence-dir DIR] [--no-cleanup]
```

### Available Features
- `theme-mode-toggle` — Dark/light theme mode transitions with portal sync

### Theme Mode Toggle Test

Tests the dark ↔ light theme toggle with portal verification:

```bash
./control-noctalia feature theme-mode-toggle
```

**Test Steps:**
1. Checks prerequisites (compositor, Noctalia IPC, theme tools)
2. Captures resolved theme mode via `theme-mode-get` (light|dark); portal optional
3. Executes `noctalia msg theme-mode-toggle`
4. Waits 0.5s for portal sync
5. Verifies `color-scheme` changed in portal
6. Restores initial theme mode
7. Archives evidence or preserves with `--no-cleanup`

**Exit Codes:**
- `0` (PASS) — Theme toggled and portal color-scheme changed
- `1` (FAIL) — Compositor present but portal unchanged (indicates bug)
- `2` (INCONCLUSIVE) — No compositor, Noctalia not running, or no theme tools

**Evidence:**
- `test.log` — Test execution log
- `initial-mode.txt` — Initial theme mode
- `before-*` / `after-*` — Portal state snapshots
- `toggle-output.txt` — IPC command output
- `result.txt` — PASS/FAIL verdict

### Options
- `--evidence-dir DIR` — Custom evidence directory (default: `/tmp/noctalia-verify-evidence`)
- `--no-cleanup` — Keep evidence directory after test (default: archive to .tar.gz)

---

## 3. IPC Control Commands

**Script**: `control-noctalia <command>`

Direct IPC wrappers for Noctalia control operations.

### Usage
```bash
./control-noctalia <command> [args...]
```

### Available Commands

**Connectivity:**
- `ping` — Test IPC (returns PONG or ERROR)
- `status` — Get full status JSON

**Theme Operations:**
- `get-theme-mode` — Get current mode (dark/light/auto)
- `set-theme-mode <mode>` — Set mode explicitly
- `toggle-theme-mode` — Toggle between dark and light

**Panel Operations:**
- `open-panel <id> [context]` — Open panel (launcher, control-center, etc.)
- `toggle-panel <id> [context]` — Toggle panel
- `close-panel [id]` — Close active or named panel

**Notification Operations:**
- `get-dnd` — Get Do Not Disturb status
- `set-dnd <state>` — Set DND (on/off/true/false/1/0)
- `toggle-dnd` — Toggle DND mode

**Raw IPC:**
- `msg <cmd> [args...]` — Pass-through to `noctalia msg`

### Examples
```bash
# Health check
./control-noctalia ping

# Theme control
./control-noctalia toggle-theme-mode
./control-noctalia get-theme-mode

# Panel control
./control-noctalia open-panel launcher
./control-noctalia toggle-panel control-center audio

# Notifications
./control-noctalia set-dnd on
./control-noctalia toggle-dnd

# Raw IPC
./control-noctalia msg bar-toggle
```

---

## 4. Feature Documentation

See `features/` directory for detailed feature specifications:

- **[features/theme-mode-toggle.md](features/theme-mode-toggle.md)** — Theme mode transitions, portal sync, gotchas (PER-328)
- **[features/README.md](features/README.md)** — Feature inventory

Each feature file includes:
- **Sub-features** — Specific capabilities being tested
- **User paths** — How to trigger the feature (IPC, UI, keyboard)
- **Expected behavior** — Observable outcomes
- **Driving it** — How to automate testing with `control-noctalia`
- **Gotchas** — Known timing issues, race conditions, edge cases

---

## 5. Evidence & Artifacts

Evidence is captured automatically during feature tests and saved to:

```
/tmp/noctalia-verify-evidence/<feature-name>-<timestamp>/
  test.log              — Test execution log
  initial-mode.txt      — Initial state
  before-*.txt          — Pre-test snapshots
  after-*.txt           — Post-test snapshots
  toggle-output.txt     — IPC command output
  result.txt            — PASS/FAIL/INCONCLUSIVE verdict
```

By default, evidence is archived to `.tar.gz` after test completion. Use `--no-cleanup` to preserve uncompressed directory.

### Committing Evidence

```bash
# Run test with preserved evidence
./control-noctalia feature theme-mode-toggle --no-cleanup

# Copy to skill proof directory
mkdir -p .cursor/skills/verify-noctalia/proof
cp -r /tmp/noctalia-verify-evidence/* .cursor/skills/verify-noctalia/proof/

# Commit
git add .cursor/skills/verify-noctalia/proof/
git commit -m "feat: add theme-toggle verification evidence"
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

## 6. CLI Integration

The `control-noctalia` script is wired into the Noctalia binary as `noctalia verify`:

```bash
# Via script (always available)
cd .cursor/skills/verify-noctalia
./control-noctalia doctor
./control-noctalia feature theme-mode-toggle

# Via CLI (after build)
noctalia verify doctor
noctalia verify feature theme-mode-toggle
noctalia verify list
```

### Build Requirements

The verify command requires C++23 with `std::print` support:
- GCC 13+ or Clang 16+
- `src/cli/verify.cpp` — CLI implementation
- `src/cli/verify.h` — CLI header
- `src/cli/schema_verify.h` — CLI schema

### How It Works

`noctalia verify` locates the skill directory and invokes `control-noctalia`:

1. Searches `.cursor/skills/verify-noctalia/` relative to `$PWD`
2. Falls back to installed location (e.g., `/usr/share/noctalia/skills/verify-noctalia/`)
3. Executes `control-noctalia <subcommand>` with arguments
4. Returns the same exit codes (0=PASS, 1=FAIL, 2=INCONCLUSIVE)

---

## Feature Test Scenarios

See `features/` for detailed feature specifications:
- **[features/theme-mode-toggle.md](features/theme-mode-toggle.md)** — Dark/light theme toggle with portal sync, gotchas (PER-328)
- **[features/README.md](features/README.md)** — Feature inventory

---

## Cloud VM / Headless Workflow

When compositor is unavailable (cloud VM, CI without Wayland):

### Doctor Returns INCONCLUSIVE

```bash
cd .cursor/skills/verify-noctalia
./control-noctalia doctor

# Output:
# === Noctalia Doctor Check ===
# ✗ No supported compositor detected
# ✗ Noctalia not running
# ✓ gsettings available
# ✓ busctl available
#
# STATUS: INCONCLUSIVE (no compositor detected)
# Verification requires Hyprland, Sway, or Niri compositor.
#
# Exit code: 2
```

### Feature Tests Also Return INCONCLUSIVE

```bash
./control-noctalia feature theme-mode-toggle

# Output:
# INCONCLUSIVE: No compositor detected (requires Hyprland/Sway/Niri)
#
# Exit code: 2
```

### Report INCONCLUSIVE Evidence

The skill is still valuable even when full runtime testing is blocked:
- ✅ Control CLI created and executable
- ✅ Feature documentation complete
- ✅ C++ verify command wired into Noctalia binary
- ✅ Exit codes properly defined (0=PASS, 1=FAIL, 2=INCONCLUSIVE)
- ⚠️ Cannot execute without Wayland compositor (expected on cloud VM)

**Expected behavior on Hyprland desktop:**
- Doctor returns exit 0 (PASS) when Noctalia is running
- Feature tests execute and verify portal changes
- Evidence is captured showing before/after portal state

Ship the skill anyway — it's ready for local dev, CI with Wayland, or user testing.

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
- Doctor returns exit 2 (INCONCLUSIVE) — expected on cloud VM
- On local machine: ensure `$WAYLAND_DISPLAY` is set
- Check compositor is running: `ps aux | grep -E "hyprland|sway|niri"`

### "IPC not responding"
- Ensure Noctalia is running: `pgrep noctalia`
- Start Noctalia: `noctalia --daemon`
- Check IPC socket: `ls -la $XDG_RUNTIME_DIR/noctalia.sock`

### "Theme tools unavailable"
- Install gsettings: `sudo apt-get install libglib2.0-bin`
- Or install dconf: `sudo apt-get install dconf-cli`
- Feature tests will return INCONCLUSIVE without theme tools

---

## References

- [Noctalia README](../../../README.md) — Project overview
- [BUILDING.md](../../../BUILDING.md) — Build dependencies
- [example.toml](../../../example.toml) — Configuration reference
- [features/theme-mode-toggle.md](features/theme-mode-toggle.md) — Detailed theme toggle specification

---

**Build the Lever**: This skill provides verification-as-infrastructure. Doctor validates prerequisites. Feature tests automate manual testing. Control CLI makes IPC accessible. Evidence makes proof portable. Together: tight iteration loops, reproducible verification, confident deploys.
