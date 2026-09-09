# Panel Toggle

Verification of panel open/toggle/close commands with context support.

## Sub-features

1. **Panel open by ID**: `launcher`, `control-center`, `settings`, `wallpaper`, etc.
2. **Panel toggle**: Open if closed, close if open
3. **Context parameter**: Panel-specific navigation (e.g., `control-center audio`)
4. **Close active panel**: Close without specifying ID
5. **Panel state persistence**: Survives focus changes (not compositor-driven)

## How to get to it (user POV)

### IPC Commands

```bash
# Open launcher
noctalia msg panel-open launcher

# Open control center at audio tab
noctalia msg panel-open control-center audio

# Toggle wallpaper picker
noctalia msg panel-toggle wallpaper

# Close active panel
noctalia msg panel-close
```

### UI Triggers

- **Launcher**: Super key, bar widget click, screen corner
- **Control center**: Bar widget click, keyboard shortcut
- **Wallpaper**: Right-click on desktop (if enabled)
- **Settings**: Bar settings widget, `noctalia msg settings-open`

### Expected Visual Changes

- Panel surface appears as layer-shell overlay
- Panel animates in (slide/fade depending on config)
- Keyboard focus moves to panel input fields
- Clicking outside panel closes it (except locked panels)

## Driving it with control-noctalia

```bash
# Test sequence
EVIDENCE_DIR="/tmp/noctalia-verify-evidence/panel-toggle-$(date +%s)"
mkdir -p "$EVIDENCE_DIR"

# 1. Get baseline status
noctalia msg status > "$EVIDENCE_DIR/status-initial.json"

# Extract active panel (if any)
INITIAL_PANEL=$(jq -r '.panel // "none"' "$EVIDENCE_DIR/status-initial.json" 2>/dev/null || echo "none")
echo "Initial panel: $INITIAL_PANEL"

# 2. Open launcher
echo "Opening launcher..."
./control-noctalia open-panel launcher | tee "$EVIDENCE_DIR/open-launcher.txt"
sleep 0.3

noctalia msg status > "$EVIDENCE_DIR/status-after-open.json"
OPEN_PANEL=$(jq -r '.panel // "none"' "$EVIDENCE_DIR/status-after-open.json" 2>/dev/null || echo "none")

if [[ "$OPEN_PANEL" == "launcher" ]]; then
  echo "✓ Launcher opened"
else
  echo "✗ Expected panel=launcher, got: $OPEN_PANEL"
fi

# 3. Toggle (should close)
echo "Toggling launcher..."
./control-noctalia toggle-panel launcher | tee "$EVIDENCE_DIR/toggle-close.txt"
sleep 0.3

noctalia msg status > "$EVIDENCE_DIR/status-after-toggle-close.json"
CLOSED_PANEL=$(jq -r '.panel // "none"' "$EVIDENCE_DIR/status-after-toggle-close.json" 2>/dev/null || echo "none")

if [[ "$CLOSED_PANEL" == "none" ]]; then
  echo "✓ Launcher closed"
else
  echo "✗ Expected panel=none, got: $CLOSED_PANEL"
fi

# 4. Toggle again (should re-open)
echo "Re-toggling launcher..."
./control-noctalia toggle-panel launcher | tee "$EVIDENCE_DIR/toggle-open.txt"
sleep 0.3

noctalia msg status > "$EVIDENCE_DIR/status-after-toggle-open.json"
REOPEN_PANEL=$(jq -r '.panel // "none"' "$EVIDENCE_DIR/status-after-toggle-open.json" 2>/dev/null || echo "none")

if [[ "$REOPEN_PANEL" == "launcher" ]]; then
  echo "✓ Launcher re-opened"
else
  echo "✗ Expected panel=launcher, got: $REOPEN_PANEL"
fi

# 5. Close explicitly
noctalia msg panel-close
sleep 0.3

noctalia msg status > "$EVIDENCE_DIR/status-final.json"
FINAL_PANEL=$(jq -r '.panel // "none"' "$EVIDENCE_DIR/status-final.json" 2>/dev/null || echo "none")

if [[ "$FINAL_PANEL" == "none" ]]; then
  echo "✓ Panel explicitly closed"
  echo "PASS" > "$EVIDENCE_DIR/result.txt"
else
  echo "✗ Panel not closed: $FINAL_PANEL"
  echo "FAIL" > "$EVIDENCE_DIR/result.txt"
fi

echo "Evidence: $EVIDENCE_DIR"
```

## Gotchas

### Panel Context Persistence (PER-1269 / #4157)

**Issue**: When toggling a panel with context (e.g., `noctalia msg panel-toggle control-center audio`), the first toggle opens at the specified tab. A second toggle (without context) should re-open at the *last used* tab, but historically may have reverted to default.

**Expected behavior**:

```bash
# First toggle: Opens at audio tab
noctalia msg panel-toggle control-center audio
# Panel visible, audio tab active

# Second toggle: Closes
noctalia msg panel-toggle control-center
# Panel hidden

# Third toggle: Should re-open at audio tab (last context)
noctalia msg panel-toggle control-center
# Panel visible, audio tab active (NOT default tab)
```

**Verification**:

Requires inspecting panel state from status JSON or visual confirmation (screenshot). Automated verification can check:

```bash
# Open with context
noctalia msg panel-open control-center audio
PANEL_STATE=$(noctalia msg status | jq -r '.controlCenter.activeTab // "unknown"')
echo "Active tab after open: $PANEL_STATE"

# Close and re-open without context
noctalia msg panel-close
noctalia msg panel-open control-center

RESTORED_TAB=$(noctalia msg status | jq -r '.controlCenter.activeTab // "unknown"')
echo "Active tab after restore: $RESTORED_TAB"

[[ "$PANEL_STATE" == "$RESTORED_TAB" ]] && echo "✓ Context persisted" || echo "✗ Context lost"
```

**Status**: This may require status JSON enhancements to expose panel context. Current verification focuses on open/close states.

### Launcher Focus and Input

**Launcher panel** expects keyboard focus to immediately allow typing. On some compositors (e.g., tiling WMs without auto-focus), the launcher may open but not receive focus, requiring an explicit focus protocol call.

**Symptom**: Launcher opens, but typing does nothing until the panel surface is clicked.

**Compositor-specific**:
- Hyprland: Focus works (layer-shell surfaces auto-focus by default)
- Sway: Focus works with `layer_effects { keyboard_interactive = "on_demand" }`
- Labwc: May require explicit `wlr-layer-shell` focus hint

**Verification**: Cannot fully automate keyboard input without compositor support for virtual input. Visual verification confirms focus ring appears in the launcher search box.

### Panel Animations

Panel transitions (slide, fade) have configurable durations (default ~200ms). Verification timing (`sleep 0.3`) allows animation to complete before sampling panel state.

**Fast compositor check**: If `noctalia msg status` immediately after `panel-open` shows `panel: null`, the panel hasn't finished opening. Add 100-300ms delay.

### Multiple Monitors

Panels typically anchor to the monitor with pointer focus or the primary monitor. On multi-monitor setups:

- Panel may appear on a different monitor than expected
- Panel-close closes the active panel regardless of monitor

**Verification note**: Multi-monitor tests should include `hyprctl monitors` or `swaymsg -t get_outputs` to confirm which output received the panel.

### Panel Priority

Only one panel is visible at a time. Opening a new panel closes the previous:

```bash
noctalia msg panel-open launcher
# Launcher is active

noctalia msg panel-open control-center
# Control center is now active, launcher implicitly closed
```

**Verification**: Status JSON should show only one panel ID, never multiple.

### Settings Panel vs Settings Command

The `settings-open` command opens a persistent **window** (not a panel), which does not follow panel-open/toggle/close lifecycle. It's a separate top-level window surface.

```bash
# Panel
noctalia msg panel-open control-center
noctalia msg panel-close  # Closes control center

# Window (not affected by panel-close)
noctalia msg settings-open
noctalia msg settings-close  # Separate command
```

**Test scope**: Panel tests cover `panel-open`, `panel-toggle`, `panel-close`. Settings window is a separate feature.
