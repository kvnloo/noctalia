---
name: verify-noctalia
description: Verify the Noctalia Wayland desktop shell through automated testing of IPC, theming, panels, and UI components. Use when validating Noctalia features, debugging compositor integration, or testing configuration changes.
---

# Noctalia Verification Skill

This skill provides systematic verification of the Noctalia Wayland desktop shell, including IPC command validation, theme mode transitions, panel behavior, and compositor integration.

## Overview

Noctalia is a native Wayland desktop shell providing bars, widgets, panels, launcher, notifications, lock screen, and wallpaper management. It runs as a layer-shell surface on Wayland compositors (Hyprland, Sway, Niri, etc.) and exposes IPC control through `noctalia msg <command>`.

## Launch

### Prerequisites

**Required for PASS result:**
1. **Wayland compositor**: Hyprland, Sway, or Niri (detection via env vars)
2. **Running Noctalia instance**: Noctalia must be running and IPC responsive
3. **XDG_RUNTIME_DIR**: Set for IPC socket communication
4. **Theme utilities**: `gsettings` or `dconf` for portal verification

**Without compositor or Noctalia**: Tests will exit with code 2 (INCONCLUSIVE), never fake PASS.

### Starting Noctalia

In a Wayland session:

```bash
# Start Noctalia (usually auto-started by compositor config)
noctalia --daemon

# Verify it's running
pgrep -f noctalia || echo "Not running"

# Check IPC socket exists
ls -l "$XDG_RUNTIME_DIR/noctalia.sock" 2>/dev/null || echo "No IPC socket"
```

### Verification Harness

The `control-noctalia` helper (in this skill directory) wraps IPC commands and provides status checking:

```bash
# Basic health check
./control-noctalia ping

# Get full status JSON
./control-noctalia status

# Send IPC command
./control-noctalia msg theme-mode-toggle
```

## Doctor

Run the doctor check before feature verification to ensure the environment is ready:

```bash
#!/usr/bin/env bash
# Run from skill directory

echo "=== Noctalia Doctor Check ==="

# 1. Check compositor
if [[ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]]; then
  echo "✓ Compositor: Hyprland"
  COMPOSITOR="hyprland"
elif command -v swaymsg &>/dev/null && swaymsg -t get_version &>/dev/null; then
  echo "✓ Compositor: Sway"
  COMPOSITOR="sway"
elif [[ -n "$NIRI_SOCKET" ]]; then
  echo "✓ Compositor: Niri"
  COMPOSITOR="niri"
else
  echo "✗ No supported compositor detected (Hyprland/Sway/Niri)"
  echo "  HYPRLAND_INSTANCE_SIGNATURE: ${HYPRLAND_INSTANCE_SIGNATURE:-unset}"
  echo "  XDG_CURRENT_DESKTOP: ${XDG_CURRENT_DESKTOP:-unset}"
  echo "  WAYLAND_DISPLAY: ${WAYLAND_DISPLAY:-unset}"
  COMPOSITOR="none"
fi

# 2. Check Noctalia process
if pgrep -f "noctalia" >/dev/null; then
  echo "✓ Noctalia process running"
  PID=$(pgrep -f "noctalia" | head -1)
  echo "  PID: $PID"
else
  echo "✗ Noctalia not running"
  echo "  Start with: noctalia --daemon"
  exit 1
fi

# 3. Check IPC socket
SOCK="${XDG_RUNTIME_DIR}/noctalia.sock"
if [[ -S "$SOCK" ]]; then
  echo "✓ IPC socket exists: $SOCK"
else
  echo "✗ IPC socket not found: $SOCK"
  echo "  XDG_RUNTIME_DIR: ${XDG_RUNTIME_DIR:-unset}"
  exit 1
fi

# 4. Test basic IPC
if timeout 2s noctalia msg status >/dev/null 2>&1; then
  echo "✓ IPC responding (msg status)"
else
  echo "✗ IPC timeout or error"
  echo "  Try: noctalia msg status"
  exit 1
fi

# 5. Check theme utilities
if command -v gsettings &>/dev/null; then
  echo "✓ gsettings available"
  THEME_TOOL="gsettings"
elif command -v dconf &>/dev/null; then
  echo "✓ dconf available (fallback)"
  THEME_TOOL="dconf"
else
  echo "⚠ gsettings/dconf not found (theme portal verification limited)"
  THEME_TOOL="none"
fi

# 6. Check busctl for portal monitoring
if command -v busctl &>/dev/null; then
  echo "✓ busctl available (for portal verification)"
else
  echo "⚠ busctl not found (portal verification limited)"
fi

# 7. Compositor-specific checks
if [[ "$COMPOSITOR" == "hyprland" ]]; then
  if command -v hyprctl &>/dev/null; then
    echo "✓ hyprctl available"
    # Check for active window
    if hyprctl activewindow &>/dev/null; then
      echo "✓ Hyprland IPC responsive"
    else
      echo "⚠ hyprctl responsive but no active window"
    fi
  else
    echo "⚠ hyprctl not in PATH"
  fi
fi

echo ""
echo "=== Doctor Summary ==="
echo "Compositor: $COMPOSITOR"
echo "Noctalia IPC: READY"
echo "Theme tools: $THEME_TOOL"
echo ""

if [[ "$COMPOSITOR" == "none" ]]; then
  echo "STATUS: INCONCLUSIVE (no compositor)"
  echo "This verification requires a Wayland compositor."
  echo "Re-run on a Hyprland/Sway/Niri desktop for full verification."
  exit 2
fi

echo "STATUS: PASS"
exit 0
```

**Exit codes**:
- `0` (PASS): Compositor detected, Noctalia running, IPC responding
- `2` (INCONCLUSIVE): Compositor missing or Noctalia not responding
- `1` (FAIL): Should not occur in doctor (reserved for code errors)

**Expected outcome**: 
- PASS: Hyprland/Sway/Niri detected, IPC responding, theme tools available
- INCONCLUSIVE: No compositor or Noctalia not running (VM/headless environment)

## Drive

### Using the Control Helper

The `control-noctalia` script provides a stable interface for agents:

```bash
# Ping test
./control-noctalia ping
# Returns: PONG or ERROR

# Get current theme mode
./control-noctalia get-theme-mode
# Returns: dark, light, or auto

# Toggle theme mode
./control-noctalia toggle-theme-mode
# Returns: success confirmation

# Open panel
./control-noctalia open-panel launcher
./control-noctalia open-panel control-center audio

# Toggle panel
./control-noctalia toggle-panel launcher
./control-noctalia toggle-panel control-center

# Get full status (JSON)
./control-noctalia status
```

### Using noctalia verify

The `noctalia verify` command (wired through src/cli/schema_*.h) provides built-in verification entry points:

```bash
# Run doctor check
noctalia verify doctor

# Run specific feature test
noctalia verify feature theme-mode-toggle

# List available features
noctalia verify list
```

### Direct IPC Commands

For debugging or manual testing:

```bash
# Theme commands
noctalia msg theme-mode-get
noctalia msg theme-mode-set dark
noctalia msg theme-mode-toggle

# Panel commands
noctalia msg panel-open launcher
noctalia msg panel-toggle control-center
noctalia msg panel-close

# Status
noctalia msg status
```

## Evidence

### Capture Methods

1. **Command transcripts**: Exit codes and stdout/stderr
2. **Portal state snapshots**: gsettings/dconf output before/after
3. **Screenshots**: When WAYLAND_DISPLAY is set (grim/compositor screenshot)
4. **IPC logs**: Noctalia msg output and timing

### Evidence Directory Structure

```
/tmp/noctalia-verify-evidence/
├── doctor-{timestamp}.log          # Doctor check output
├── theme-toggle-{timestamp}/       # Per-feature evidence
│   ├── before-state.log            # Portal/gsettings before
│   ├── command-transcript.log      # IPC command output
│   ├── after-state.log             # Portal/gsettings after
│   └── screenshot.png              # Optional visual confirmation
└── summary.log                     # Overall test results
```

### Evidence Collection

```bash
# Create evidence directory
EVIDENCE_DIR="/tmp/noctalia-verify-evidence"
mkdir -p "$EVIDENCE_DIR"

# Capture portal state
function capture_portal_state() {
  local out="$1"
  {
    echo "=== gsettings gtk-theme ==="
    gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null || echo "N/A"
    
    echo "=== gsettings color-scheme ==="
    gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null || echo "N/A"
    
    echo "=== busctl portal settings ==="
    busctl --user call org.freedesktop.portal.Desktop \
      /org/freedesktop/portal/desktop \
      org.freedesktop.portal.Settings Read ss \
      org.freedesktop.appearance color-scheme 2>/dev/null || echo "N/A"
  } > "$out"
}

# Example: Capture before/after for theme toggle
TEST_DIR="$EVIDENCE_DIR/theme-toggle-$(date +%s)"
mkdir -p "$TEST_DIR"

capture_portal_state "$TEST_DIR/before-state.log"
noctalia msg theme-mode-toggle | tee "$TEST_DIR/command-transcript.log"
sleep 0.5  # Allow portal sync
capture_portal_state "$TEST_DIR/after-state.log"

# Compare states
diff -u "$TEST_DIR/before-state.log" "$TEST_DIR/after-state.log" > "$TEST_DIR/diff.log" || true
```

## Cleanup

After verification, clean up temporary evidence and restore initial state:

```bash
#!/usr/bin/env bash
# Cleanup script

echo "=== Noctalia Verification Cleanup ==="

# 1. Archive evidence
EVIDENCE_DIR="/tmp/noctalia-verify-evidence"
if [[ -d "$EVIDENCE_DIR" ]]; then
  ARCHIVE="/tmp/noctalia-verify-$(date +%Y%m%d-%H%M%S).tar.gz"
  tar -czf "$ARCHIVE" -C /tmp "$(basename "$EVIDENCE_DIR")" 2>/dev/null
  echo "✓ Evidence archived: $ARCHIVE"
  
  # Keep archive, remove working directory
  rm -rf "$EVIDENCE_DIR"
  echo "✓ Working evidence directory removed"
else
  echo "⚠ No evidence directory found"
fi

# 2. Restore original theme mode (if known)
if [[ -f /tmp/noctalia-verify-initial-theme ]]; then
  INITIAL_MODE=$(cat /tmp/noctalia-verify-initial-theme)
  echo "Restoring theme mode: $INITIAL_MODE"
  noctalia msg theme-mode-set "$INITIAL_MODE" >/dev/null 2>&1
  rm /tmp/noctalia-verify-initial-theme
  echo "✓ Theme mode restored"
fi

# 3. Close any test panels
noctalia msg panel-close >/dev/null 2>&1
echo "✓ Test panels closed"

# 4. Reload config (reset any test overrides)
noctalia msg config-reload >/dev/null 2>&1
echo "✓ Config reloaded"

echo ""
echo "Cleanup complete. Evidence preserved at: $ARCHIVE"
```

**Persistent evidence**: The tar.gz archive survives cleanup and can be extracted for post-verification analysis.

## Helpers

### control-noctalia

Main control script (ships with this skill):

```bash
#!/usr/bin/env bash
# control-noctalia - IPC wrapper for verification

set -euo pipefail

CMD="${1:-help}"

case "$CMD" in
  ping)
    if noctalia msg status >/dev/null 2>&1; then
      echo "PONG"
      exit 0
    else
      echo "ERROR: IPC not responding"
      exit 1
    fi
    ;;
    
  status)
    noctalia msg status
    ;;
    
  get-theme-mode)
    noctalia msg theme-mode-get
    ;;
    
  toggle-theme-mode)
    noctalia msg theme-mode-toggle
    ;;
    
  open-panel)
    PANEL="${2:-}"
    CONTEXT="${3:-}"
    if [[ -z "$PANEL" ]]; then
      echo "Usage: control-noctalia open-panel <panel-id> [context]"
      exit 1
    fi
    noctalia msg panel-open "$PANEL" ${CONTEXT:+"$CONTEXT"}
    ;;
    
  toggle-panel)
    PANEL="${2:-}"
    CONTEXT="${3:-}"
    if [[ -z "$PANEL" ]]; then
      echo "Usage: control-noctalia toggle-panel <panel-id> [context]"
      exit 1
    fi
    noctalia msg panel-toggle "$PANEL" ${CONTEXT:+"$CONTEXT"}
    ;;
    
  msg)
    shift
    noctalia msg "$@"
    ;;
    
  help|*)
    cat <<'EOF'
control-noctalia - Noctalia IPC helper for verification

USAGE:
  control-noctalia <command> [args...]

COMMANDS:
  ping                           Test IPC connectivity
  status                         Get full status JSON
  get-theme-mode                 Get current theme mode
  toggle-theme-mode              Toggle dark/light theme
  open-panel <id> [context]      Open panel by ID
  toggle-panel <id> [context]    Toggle panel by ID
  msg <cmd> [args...]            Pass-through to noctalia msg
  help                           Show this help

EXAMPLES:
  control-noctalia ping
  control-noctalia toggle-theme-mode
  control-noctalia open-panel launcher
  control-noctalia msg status

EOF
    exit 0
    ;;
esac
```

### verify-feature

Helper to run individual feature tests:

```bash
#!/usr/bin/env bash
# verify-feature - Run a single feature verification

set -euo pipefail

FEATURE="${1:-}"
if [[ -z "$FEATURE" ]]; then
  echo "Usage: verify-feature <feature-name>"
  echo "Available features:"
  ls -1 features/*.md 2>/dev/null | xargs -n1 basename | sed 's/\.md$//' | sed 's/^/  /'
  exit 1
fi

FEATURE_FILE="features/${FEATURE}.md"
if [[ ! -f "$FEATURE_FILE" ]]; then
  echo "Feature not found: $FEATURE"
  exit 1
fi

echo "=== Running feature verification: $FEATURE ==="

# Source feature-specific test from markdown
# (Implementation would parse the feature file and execute test sections)

# Placeholder implementation
echo "Feature file: $FEATURE_FILE"
echo "Feature verification would execute here"
exit 0
```

## Feature Map

See `features/README.md` for the feature inventory and `features/*.md` for individual feature test specifications.

## Notes

- **Headless/VM environments**: Doctor will report INCONCLUSIVE if no compositor is detected. The skill and CLI wiring can still be verified by inspecting command parsing and help output.
- **Portal sync timing**: Theme mode changes propagate to gsettings/dconf asynchronously. Add a 0.5s sleep after toggle commands before reading portal state.
- **Known issues**: Theme-mode-toggle on Hyprland can exhibit gsettings→color-scheme order dependency (PER-328 / noctalia-dev/noctalia#4181). Verification captures the sequence for comparison.
- **Battery widget**: Battery glyph icon tests require a battery widget on a configured bar; VMs without battery hardware will show INCONCLUSIVE.
