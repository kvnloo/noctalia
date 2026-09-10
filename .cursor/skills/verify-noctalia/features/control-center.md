# Control Center Feature

## Description

The Noctalia control center is a panel providing quick access to system settings: network, Bluetooth, audio, brightness, power profiles, and shell preferences. Opens via bar widget click or IPC command.

## Configuration

Control center behavior is configured in `[shell.panel]` and `[control_center.*]`:
```toml
[shell.panel]
control_center_placement = "attached"  # attached | floating
open_near_click_control_center = false # follow bar click location

[control_center.calendar]
enabled = true
show_week_numbers = true
```

## IPC Commands

### Open Control Center
```bash
noctalia msg panel-open control-center
```
Opens the control center panel.

### Close Control Center
```bash
noctalia msg panel-close control-center
```
Closes the control center panel.

### Toggle Control Center
```bash
noctalia msg panel-toggle control-center
```
Toggles control center open/closed.

## Test Scenarios

### Scenario 1: Open and Close
**Goal**: Verify control center opens and closes cleanly.

**Steps**:
1. Launch Noctalia
2. Capture screenshot of desktop
3. Execute `noctalia msg panel-open control-center`
4. Wait 500ms for animation
5. Capture screenshot showing control center
6. Execute `noctalia msg panel-close control-center`
7. Capture screenshot showing control center closed

**Expected**:
- Control center panel appears with tabs/sections visible
- Panel animates in/out smoothly
- Clicking outside closes panel (if enabled)

**Evidence**:
- Screenshots: desktop, control-center-open, control-center-closed
- IPC command logs
- Shell logs: no errors during open/close

### Scenario 2: Network Tab
**Goal**: Verify network quick settings.

**Steps**:
1. Open control center
2. Navigate to network tab
3. Verify WiFi networks listed (if available)
4. Toggle WiFi on/off
5. Verify state changes reflect in UI

**Expected**:
- WiFi networks appear when WiFi enabled
- Toggle button reflects current state
- Connecting to network works via UI

**Evidence**:
- Screenshot of network tab
- NetworkManager status before/after toggle

### Scenario 3: Bluetooth Tab
**Goal**: Verify Bluetooth quick settings.

**Steps**:
1. Open control center
2. Navigate to Bluetooth tab
3. Toggle Bluetooth on/off
4. Verify paired devices listed (if any)

**Expected**:
- Bluetooth devices listed when enabled
- Toggle reflects BlueZ service state
- Pair/unpair actions work

**Evidence**:
- Screenshot of Bluetooth tab
- `bluetoothctl` status comparison

### Scenario 4: Audio Controls
**Goal**: Verify audio volume and device selection.

**Steps**:
1. Open control center
2. Navigate to audio section
3. Adjust volume slider
4. Verify volume changes reflect in PipeWire
5. Switch audio output device (if multiple available)

**Expected**:
- Volume slider moves smoothly
- PipeWire volume matches UI
- Device selection changes active sink

**Evidence**:
- Screenshot of audio controls
- `pactl` or `wpctl` output showing volume/device

### Scenario 5: Brightness Control
**Goal**: Verify display brightness adjustment.

**Steps**:
1. Open control center
2. Adjust brightness slider
3. Verify backlight changes (if supported)

**Expected**:
- Slider moves smoothly
- Backlight reflects slider value
- ddcutil or kernel backlight updated

**Evidence**:
- Screenshot of brightness control
- Backlight sysfs/ddcutil reading

### Scenario 6: Calendar
**Goal**: Verify calendar widget in control center.

**Steps**:
1. Open control center
2. Navigate to calendar tab
3. Verify current date highlighted
4. Check events display (if calendar accounts configured)

**Expected**:
- Calendar shows current month
- Current day highlighted
- Events from CalDAV/Google Calendar appear

**Evidence**:
- Screenshot of calendar view
- Calendar config snippet

## Common Issues

### Control Center Won't Open
- **Cause**: Panel surface creation failed
- **Diagnosis**: Check shell logs for Wayland protocol errors
- **Fix**: Verify compositor supports layer-shell

### Network Tab Empty
- **Cause**: NetworkManager not running or not accessible
- **Diagnosis**: Check `systemctl status NetworkManager`, D-Bus session
- **Fix**: Start NetworkManager, verify D-Bus permissions

### Bluetooth Not Working
- **Cause**: BlueZ service not running
- **Diagnosis**: Check `systemctl status bluetooth`
- **Fix**: Enable and start `bluetooth.service`

### Audio Controls Inactive
- **Cause**: PipeWire not running or no audio devices
- **Diagnosis**: Check `pipewire --version`, `pactl list sinks`
- **Fix**: Start PipeWire, verify audio hardware

### Brightness Slider No Effect
- **Cause**: No backlight control available
- **Diagnosis**: Check `/sys/class/backlight/`, `ddcutil detect`
- **Fix**: Enable backlight support in kernel or install ddcutil

## Verification Checklist

- [ ] Control center opens on command
- [ ] Control center closes cleanly
- [ ] Network tab shows WiFi networks
- [ ] Bluetooth tab lists devices
- [ ] Audio volume slider works
- [ ] Brightness slider works (if supported)
- [ ] Calendar shows current date
- [ ] Panel placement (attached/floating) respected
- [ ] No crashes during tab navigation
- [ ] Animations smooth

## Evidence Artifacts

Capture:
- **Screenshots**: Control center main view, each tab (network, Bluetooth, audio, calendar)
- **Logs**: Shell output during open/close, any D-Bus errors
- **Config**: `[control_center.*]` and `[shell.panel]` excerpts
- **System State**: NetworkManager status, BlueZ status, PipeWire devices
