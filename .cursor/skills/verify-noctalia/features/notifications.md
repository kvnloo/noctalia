# Notifications Feature

## Description

Noctalia provides a native notification daemon implementing the FreeDesktop Desktop Notifications Specification. Notifications appear as toasts, can be organized by urgency, filtered, and stored in history with clipboard integration.

## Configuration

Notifications are configured in `[notification]`:
```toml
[notification]
enabled = true
position = "top_right"  # top_left | top_center | top_right | bottom_left | bottom_center | bottom_right
timeout = 5000          # default timeout in ms (0 = no auto-dismiss)
max_visible = 3         # max concurrent toasts
history_max = 100       # max history entries
show_in_dnd = false     # show notifications in DND mode
sound_enabled = true
sound_volume = 0.5
```

## IPC Commands

### Show Notification
```bash
noctalia msg notification-show <summary> <body>
```
Displays a test notification with the given summary and body text.

Example:
```bash
noctalia msg notification-show "Test" "This is a test notification"
```

### Clear Notifications
```bash
noctalia msg notification-clear
```
Clears all visible notification toasts.

### Show Notification History
```bash
noctalia msg panel-open notifications
```
Opens the notification history panel.

### Toggle Do Not Disturb
```bash
noctalia msg notification-dnd-toggle
```
Toggles Do Not Disturb mode (suppresses notification toasts).

## D-Bus Interface

Noctalia implements `org.freedesktop.Notifications`:
```bash
# Send notification via D-Bus
gdbus call --session --dest org.freedesktop.Notifications \
  --object-path /org/freedesktop/Notifications \
  --method org.freedesktop.Notifications.Notify \
  "test-app" 0 "" "Summary" "Body text" [] {} 5000
```

## Test Scenarios

### Scenario 1: Notification Toast
**Goal**: Verify notification appears as toast.

**Steps**:
1. Launch Noctalia
2. Execute `noctalia msg notification-show "Test Title" "Test body message"`
3. Observe toast appears in configured position
4. Wait for auto-dismiss timeout
5. Verify toast disappears

**Expected**:
- Toast appears in `position` corner
- Toast shows summary, body text, app icon
- Toast auto-dismisses after `timeout`
- Sound plays if `sound_enabled`

**Evidence**:
- Screenshot of notification toast
- Shell logs showing notification received
- Audio output (if sound enabled)

### Scenario 2: Urgency Levels
**Goal**: Verify urgency affects appearance/behavior.

**Steps**:
1. Send low urgency notification (via D-Bus with urgency=0)
2. Capture screenshot
3. Send normal urgency (urgency=1)
4. Capture screenshot
5. Send critical urgency (urgency=2)
6. Verify critical notification persists (doesn't auto-dismiss)

**Expected**:
- Low urgency: subtle appearance, auto-dismisses
- Normal urgency: default appearance
- Critical urgency: prominent, stays visible until closed

**Evidence**:
- Screenshots of each urgency level
- Timeout behavior logs

### Scenario 3: Notification History
**Goal**: Verify history panel stores notifications.

**Steps**:
1. Send multiple test notifications
2. Open notification history: `noctalia msg panel-open notifications`
3. Verify all notifications listed
4. Click notification → verify action if any
5. Clear history

**Expected**:
- History panel shows all notifications
- Notifications sorted by time
- Can replay notification actions
- Clear history works

**Evidence**:
- Screenshot of history panel
- Count of notifications before/after clear

### Scenario 4: Do Not Disturb
**Goal**: Verify DND mode suppresses toasts.

**Steps**:
1. Enable DND: `noctalia msg notification-dnd-toggle`
2. Send test notification
3. Verify toast does NOT appear
4. Open history → verify notification still logged
5. Disable DND
6. Send notification → verify toast appears now

**Expected**:
- DND suppresses toasts but logs to history
- Critical urgency can bypass DND (configurable)
- DND indicator visible in UI

**Evidence**:
- Screenshots showing DND on (no toast), DND off (toast visible)
- History panel showing logged notification during DND

### Scenario 5: Notification Actions
**Goal**: Verify actionable notifications.

**Steps**:
1. Send notification with actions via D-Bus:
   ```bash
   gdbus call --session --dest org.freedesktop.Notifications \
     --object-path /org/freedesktop/Notifications \
     --method org.freedesktop.Notifications.Notify \
     "test" 0 "" "Action Test" "Click button" '["ok","OK","cancel","Cancel"]' {} 0
   ```
2. Click "OK" button in toast
3. Verify action invoked (check app/script response)

**Expected**:
- Action buttons appear in toast
- Clicking button invokes action callback
- Toast closes after action

**Evidence**:
- Screenshot of toast with action buttons
- Action callback log

### Scenario 6: Concurrent Toasts
**Goal**: Verify multiple toasts stack/queue correctly.

**Steps**:
1. Send `max_visible + 2` notifications rapidly
2. Verify only `max_visible` toasts shown at once
3. Wait for one to dismiss
4. Verify queued notification appears

**Expected**:
- Toasts stack vertically (or queue)
- Max visible limit respected
- Queue drains as toasts dismiss

**Evidence**:
- Screenshot showing multiple toasts
- Count verification script

## Common Issues

### Notifications Not Appearing
- **Cause**: Notification daemon not started or conflicting daemon
- **Diagnosis**: Check `gdbus call --session --dest org.freedesktop.Notifications --object-path /org/freedesktop/Notifications --method org.freedesktop.Notifications.GetServerInformation`
- **Fix**: Ensure Noctalia is the active notification daemon, kill competing daemons (mako, dunst, etc.)

### Notifications Appear Wrong Position
- **Cause**: Config `position` not applied or compositor anchor issue
- **Diagnosis**: Check `[notification]` config, compositor logs
- **Fix**: Reload config, verify layer-shell anchor support

### Sound Not Playing
- **Cause**: PipeWire not available or sound files missing
- **Diagnosis**: Check `assets/sounds/` exists, PipeWire running
- **Fix**: Enable PipeWire, verify sound assets installed

### History Not Persisting
- **Cause**: State store write failure (permissions, secret service)
- **Diagnosis**: Check shell logs for state store errors
- **Fix**: Verify `~/.local/state/noctalia/` writable, secret service available

## Verification Checklist

- [ ] Notification toast appears on test command
- [ ] Toast auto-dismisses after timeout
- [ ] Urgency levels affect appearance
- [ ] History panel logs all notifications
- [ ] DND mode suppresses toasts (but logs to history)
- [ ] Actions work (if supported by sender)
- [ ] Max visible limit respected
- [ ] Sound plays on notification (if enabled)
- [ ] No crashes when spamming notifications

## Evidence Artifacts

Capture:
- **Screenshots**: Toast visible, history panel, DND mode indicator, urgency variants
- **Logs**: Notification D-Bus calls, shell notification handler output
- **Config**: `[notification]` section
- **D-Bus State**: `GetServerInformation` response confirming Noctalia is handler
