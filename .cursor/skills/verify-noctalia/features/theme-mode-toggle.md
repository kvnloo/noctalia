# Theme Mode Toggle

Verification of dark/light theme mode transitions and portal synchronization.

## Sub-features

1. **Toggle dark ↔ light**: Direct mode switch
2. **Portal sync (gsettings)**: gtk-theme and color-scheme propagation
3. **Portal sync (dconf)**: Fallback when gsettings unavailable
4. **busctl verification**: XDG portal color-scheme signal
5. **Persistence**: Mode survives config reload
6. **Auto mode**: Solar schedule when latitude/longitude available

## How to get to it (user POV)

### Manual IPC

```bash
# Get current mode
noctalia msg theme-mode-get

# Toggle between dark and light
noctalia msg theme-mode-toggle

# Set specific mode
noctalia msg theme-mode-set dark
noctalia msg theme-mode-set light
noctalia msg theme-mode-set auto
```

### UI Trigger

- Control center → Appearance → Theme mode dropdown
- Bar widget gesture (left swipe on theme-mode widget)
- Keyboard shortcut (if configured)

### Expected Visual Changes

- Shell background color shifts (dark/light)
- Bar widgets change text/icon colors
- Panel backgrounds adapt to theme
- GTK applications (if portal-aware) switch themes

## Driving it with control-noctalia

```bash
# Pre-test: Save initial state
INITIAL_MODE=$(./control-noctalia get-theme-mode)
echo "$INITIAL_MODE" > /tmp/noctalia-verify-initial-theme

# Capture baseline portal state
EVIDENCE_DIR="/tmp/noctalia-verify-evidence/theme-toggle-$(date +%s)"
mkdir -p "$EVIDENCE_DIR"

gsettings get org.gnome.desktop.interface gtk-theme > "$EVIDENCE_DIR/before-gtk-theme.txt" 2>&1 || echo "N/A" > "$EVIDENCE_DIR/before-gtk-theme.txt"
gsettings get org.gnome.desktop.interface color-scheme > "$EVIDENCE_DIR/before-color-scheme.txt" 2>&1 || echo "N/A" > "$EVIDENCE_DIR/before-color-scheme.txt"

# Execute toggle
echo "Toggling theme mode..."
./control-noctalia toggle-theme-mode | tee "$EVIDENCE_DIR/toggle-output.txt"

# Wait for portal sync (known async timing)
sleep 0.5

# Capture after-state
gsettings get org.gnome.desktop.interface gtk-theme > "$EVIDENCE_DIR/after-gtk-theme.txt" 2>&1 || echo "N/A" > "$EVIDENCE_DIR/after-gtk-theme.txt"
gsettings get org.gnome.desktop.interface color-scheme > "$EVIDENCE_DIR/after-color-scheme.txt" 2>&1 || echo "N/A" > "$EVIDENCE_DIR/after-color-scheme.txt"

# Verify change occurred
BEFORE_SCHEME=$(cat "$EVIDENCE_DIR/before-color-scheme.txt")
AFTER_SCHEME=$(cat "$EVIDENCE_DIR/after-color-scheme.txt")

if [[ "$BEFORE_SCHEME" != "$AFTER_SCHEME" ]]; then
  echo "✓ Portal color-scheme changed: $BEFORE_SCHEME → $AFTER_SCHEME"
  echo "PASS" > "$EVIDENCE_DIR/result.txt"
else
  echo "✗ Portal color-scheme unchanged: $BEFORE_SCHEME"
  echo "FAIL" > "$EVIDENCE_DIR/result.txt"
fi

# Verify gtk-theme also updated
BEFORE_GTK=$(cat "$EVIDENCE_DIR/before-gtk-theme.txt")
AFTER_GTK=$(cat "$EVIDENCE_DIR/after-gtk-theme.txt")

if [[ "$BEFORE_GTK" != "$AFTER_GTK" ]]; then
  echo "✓ GTK theme changed: $BEFORE_GTK → $AFTER_GTK"
else
  echo "⚠ GTK theme unchanged (may be expected if not using adw-gtk-theme)"
fi

# Restore initial state
./control-noctalia msg theme-mode-set "$INITIAL_MODE"

echo "Evidence directory: $EVIDENCE_DIR"
```

### Automated Test Script

```bash
#!/usr/bin/env bash
# Test: theme-mode-toggle

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SKILL_DIR/test-helpers.sh"

TEST_NAME="theme-mode-toggle"
setup_test "$TEST_NAME"

# 1. Get initial mode
INITIAL_MODE=$(noctalia msg theme-mode-get)
log "Initial mode: $INITIAL_MODE"

# 2. Capture before state
capture_portal_state "before"

# 3. Toggle
log "Toggling theme mode..."
noctalia msg theme-mode-toggle > "$EVIDENCE_DIR/toggle-output.txt"
EXIT_CODE=$?

if [[ $EXIT_CODE -ne 0 ]]; then
  fail "IPC command failed with exit code $EXIT_CODE"
fi

# 4. Wait for sync
sleep 0.5

# 5. Capture after state
capture_portal_state "after"

# 6. Verify
BEFORE=$(cat "$EVIDENCE_DIR/before-color-scheme.txt")
AFTER=$(cat "$EVIDENCE_DIR/after-color-scheme.txt")

if [[ "$BEFORE" == "$AFTER" ]]; then
  fail "color-scheme unchanged: $BEFORE"
fi

# 7. Restore
noctalia msg theme-mode-set "$INITIAL_MODE" >/dev/null 2>&1

pass "Theme toggled: $BEFORE → $AFTER"
```

## Gotchas

### Portal Sync Timing (PER-328 / #4181)

**Issue**: On Hyprland, gsettings sometimes receives `gtk-theme` before `color-scheme` when the order should be reversed for proper GTK4 Adwaita theme application.

**Observation sequence**:

```
# Expected order (correct):
1. noctalia msg theme-mode-toggle
2. gsettings color-scheme updated
3. gsettings gtk-theme updated
4. GTK apps apply theme

# Observed order (Hyprland-specific race):
1. noctalia msg theme-mode-toggle
2. gsettings gtk-theme updated
3. gsettings color-scheme updated (late)
4. GTK apps partially apply (light theme with dark scheme)
```

**Verification approach**: Capture timestamps with `busctl monitor` to observe signal order:

```bash
busctl --user monitor org.gnome.desktop.interface &
MONITOR_PID=$!

noctalia msg theme-mode-toggle

sleep 1
kill $MONITOR_PID
```

**Workaround**: Application code (src/app/application_services.cpp) intentionally delays sync to batch changes. Test should verify *eventual* consistency, not immediate order.

### gsettings vs dconf

**gsettings** is preferred but requires `libglib2.0-bin`. If absent, Noctalia falls back to **dconf** with slightly different invocation:

```bash
# gsettings (preferred)
gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"

# dconf (fallback)
dconf write /org/gnome/desktop/interface/color-scheme "'prefer-dark'"
```

Verification should detect which tool is used (see Doctor check).

### Auto Mode

When `theme.mode = "auto"` in config, the resolved mode depends on solar schedule:

- Latitude/longitude from location config or system geolocation
- Day/night calculation based on civil twilight
- Toggle command cycles through dark → light → auto (not just dark/light)

**Test consideration**: Auto mode verification requires mocking time or latitude to force day/night transitions. Current verification focuses on explicit dark/light modes.

### Compositor Restart

Theme mode is persisted to `settings.toml`, so it survives:
- Noctalia restart
- Compositor restart
- System reboot

Portal state (gsettings) may reset to system defaults if not managed by a portal service. Verify persistence by:

```bash
# Save mode
noctalia msg theme-mode-set light

# Restart Noctalia
pkill noctalia
noctalia --daemon &
sleep 2

# Verify restored
[[ "$(noctalia msg theme-mode-get)" == "light" ]] && echo "✓ Persisted"
```

### No Portal Service

On minimal systems without xdg-desktop-portal, gsettings/dconf may be unavailable. Noctalia still toggles internally (for shell UI), but GTK apps won't follow. Verification result should be:

- **PASS** if Noctalia IPC confirms mode change
- **INCONCLUSIVE** if portal verification skipped (no gsettings/dconf)
- **FAIL** only if IPC command fails or mode doesn't change in `noctalia msg status` output
