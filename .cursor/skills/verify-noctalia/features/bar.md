# Bar Feature

## Description

Noctalia bars are multi-monitor Wayland layer-shell surfaces that display widgets (workspaces, taskbar, system tray, clock, media player, network, battery, etc.). Bars can be toggled, hidden, shown, and configured per-monitor.

## Configuration

Bars are defined in `config.toml`:
```toml
[bar.main]
enabled = true
output = ""  # empty = all monitors, or specific output name
position = "top"  # top | bottom | left | right
layer = "top"
height = 32
margin = [0, 0, 0, 0]  # top, right, bottom, left
padding = [4, 8]       # vertical, horizontal

[[bar.main.left]]
type = "workspaces"

[[bar.main.center]]
type = "clock"

[[bar.main.right]]
type = "tray"
```

## IPC Commands

### Toggle Bar
```bash
noctalia msg bar-toggle <bar_id>
```
Toggles visibility of the specified bar (e.g., `main`).

### Show Bar
```bash
noctalia msg bar-show <bar_id>
```
Explicitly shows a bar.

### Hide Bar
```bash
noctalia msg bar-hide <bar_id>
```
Explicitly hides a bar.

### Reload Configuration
```bash
noctalia msg reload-config
```
Hot-reloads configuration, applies bar changes without restart.

## Test Scenarios

### Scenario 1: Bar Toggle
**Goal**: Verify bar visibility toggles on/off.

**Steps**:
1. Launch Noctalia with default config containing `[bar.main]` enabled
2. Capture screenshot showing bar visible
3. Execute `noctalia msg bar-toggle main`
4. Wait 500ms for animation
5. Capture screenshot showing bar hidden
6. Execute `noctalia msg bar-toggle main` again
7. Capture screenshot showing bar visible again

**Expected**:
- Bar disappears when toggled off
- Bar reappears when toggled on
- Widgets animate smoothly

**Evidence**:
- Screenshots: `bar-visible-1.png`, `bar-hidden.png`, `bar-visible-2.png`
- IPC logs: command responses
- Shell logs: no errors during toggle

### Scenario 2: Bar Widgets
**Goal**: Verify widgets render and update.

**Steps**:
1. Configure bar with multiple widgets (clock, workspaces, tray)
2. Launch Noctalia
3. Verify clock updates every minute
4. Open an app → verify taskbar widget updates
5. Add tray icon app → verify tray widget updates

**Expected**:
- Clock shows current time, updates
- Workspaces reflect active workspace
- Tray icons appear for running apps

**Evidence**:
- Screenshot of bar with all widgets populated
- Time-series screenshots showing clock updates

### Scenario 3: Multi-Monitor Bars
**Goal**: Verify bars on multiple outputs.

**Steps**:
1. Configure multiple bars with different `output` values
2. Launch on multi-monitor setup
3. Verify each monitor shows its configured bar
4. Toggle one bar → other bars unaffected

**Expected**:
- Each monitor shows correct bar
- Bar positions/heights respect per-monitor config
- Toggle commands target specific bars

**Evidence**:
- Multi-monitor screenshot
- Per-monitor config excerpts

### Scenario 4: Bar Hot-Reload
**Goal**: Verify configuration changes apply without restart.

**Steps**:
1. Launch Noctalia with bar enabled
2. Edit `config.toml` to change bar height or widgets
3. Execute `noctalia msg reload-config`
4. Verify bar updates immediately

**Expected**:
- Bar reflects new config
- No crash or visual glitches
- IPC responds with success

**Evidence**:
- Before/after screenshots
- Config diff
- IPC reload command log

## Common Issues

### Bar Not Visible
- **Cause**: Compositor doesn't support layer-shell
- **Diagnosis**: Check compositor logs for protocol errors
- **Fix**: Use supported compositor (Hyprland, Sway, Niri)

### Bar Overlaps Windows
- **Cause**: Layer or exclusive zone misconfigured
- **Diagnosis**: Check `layer` and bar `height` in config
- **Fix**: Set `layer = "top"` and ensure exclusive zone is respected

### Bar Toggle Unresponsive
- **Cause**: IPC socket issue or shell hung
- **Diagnosis**: Check IPC socket exists, shell process running
- **Fix**: Restart shell, check logs for deadlock/panic

### Widgets Not Updating
- **Cause**: D-Bus services unavailable (tray, media, network)
- **Diagnosis**: Check D-Bus session bus, service status
- **Fix**: Ensure required services running (e.g., `bluez`, `NetworkManager`)

## Verification Checklist

- [ ] Bar appears on launch
- [ ] Bar toggles hide/show
- [ ] Widgets render correctly
- [ ] Multi-monitor bars work independently
- [ ] Hot-reload applies config changes
- [ ] No crashes during toggle/reload
- [ ] Exclusive zone respected by windows
- [ ] Animations smooth (no flicker)

## Evidence Artifacts

Capture the following for proof:
- **Screenshots**: Bar visible, hidden, multi-widget, multi-monitor
- **Logs**: Shell startup, IPC commands, config reload
- **Config**: Relevant `[bar.*]` sections
- **IPC State**: `noctalia msg --help` showing bar commands available
