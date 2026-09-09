# Notification Flow

Verification of the notification daemon, toast display, history, and Do Not Disturb (DND) mode.

## Sub-features

1. **Notification daemon registration**: Claims `org.freedesktop.Notifications` on session bus
2. **Toast display**: Incoming notifications appear as overlays
3. **Notification history**: Toasts move to history panel
4. **DND mode**: Suppress toasts (but record to history)
5. **Urgency levels**: Low, normal, critical styling
6. **Actions**: Notification buttons and default action
7. **Clear history**: IPC command to purge history

## How to get to it (user POV)

### Trigger Notification

```bash
# Using notify-send (FreeDesktop standard)
notify-send "Test Title" "This is a test notification"

# Critical urgency
notify-send -u critical "Alert" "Important message"

# With actions (requires app-id support)
notify-send --action="dismiss=Dismiss" "Action Test" "Click button"
```

### View History

- Click notification icon in bar (shows unread count)
- Notification panel opens with scrollable history
- Click notification to invoke default action
- Right-click or swipe to dismiss

### DND Toggle

```bash
# Enable DND
noctalia msg notification-dnd-set on

# Disable DND
noctalia msg notification-dnd-set off

# Toggle DND
noctalia msg notification-dnd-toggle

# Check DND status
noctalia msg notification-dnd-status
```

## Driving it with control-noctalia

```bash
EVIDENCE_DIR="/tmp/noctalia-verify-evidence/notification-$(date +%s)"
mkdir -p "$EVIDENCE_DIR"

# 1. Check daemon is registered
if busctl --user status org.freedesktop.Notifications >/dev/null 2>&1; then
  echo "✓ Notification daemon registered on session bus"
else
  echo "✗ Notification daemon not found"
  exit 1
fi

# 2. Get initial DND state
INITIAL_DND=$(noctalia msg notification-dnd-status)
echo "Initial DND: $INITIAL_DND" > "$EVIDENCE_DIR/initial-dnd.txt"

# 3. Ensure DND is off for testing
noctalia msg notification-dnd-set off

# 4. Send test notification
echo "Sending test notification..."
notify-send "Verify Test" "This is a verification notification" > "$EVIDENCE_DIR/notify-send.txt" 2>&1

# Wait for toast to display
sleep 2

# 5. Check history (notifications should be recorded)
HISTORY=$(noctalia msg status | jq -r '.notifications.count // 0')
echo "Notification count: $HISTORY" | tee "$EVIDENCE_DIR/history-count.txt"

if [[ "$HISTORY" -gt 0 ]]; then
  echo "✓ Notification recorded to history"
else
  echo "✗ No notifications in history"
fi

# 6. Test DND mode
echo "Enabling DND..."
noctalia msg notification-dnd-set on > "$EVIDENCE_DIR/dnd-on.txt"

DND_STATUS=$(noctalia msg notification-dnd-status)
if [[ "$DND_STATUS" =~ "on"|"true"|"1" ]]; then
  echo "✓ DND enabled"
else
  echo "✗ DND not enabled: $DND_STATUS"
fi

# 7. Send notification during DND (should suppress toast but record to history)
echo "Sending notification during DND..."
notify-send "DND Test" "This should be silent"

sleep 2

# Check history increased (notification recorded)
NEW_HISTORY=$(noctalia msg status | jq -r '.notifications.count // 0')
echo "Notification count after DND: $NEW_HISTORY" | tee "$EVIDENCE_DIR/history-after-dnd.txt"

if [[ "$NEW_HISTORY" -gt "$HISTORY" ]]; then
  echo "✓ Notification recorded during DND (toast suppressed)"
else
  echo "⚠ History count unchanged (may be deduplicated)"
fi

# 8. Disable DND
noctalia msg notification-dnd-set off

# 9. Clear history
echo "Clearing notification history..."
noctalia msg notification-clear-history > "$EVIDENCE_DIR/clear-history.txt"

sleep 0.5

FINAL_HISTORY=$(noctalia msg status | jq -r '.notifications.count // 0')
echo "Notification count after clear: $FINAL_HISTORY" | tee "$EVIDENCE_DIR/final-history.txt"

if [[ "$FINAL_HISTORY" -eq 0 ]]; then
  echo "✓ History cleared"
  echo "PASS" > "$EVIDENCE_DIR/result.txt"
else
  echo "✗ History not cleared: $FINAL_HISTORY"
  echo "FAIL" > "$EVIDENCE_DIR/result.txt"
fi

# Restore initial DND state
noctalia msg notification-dnd-set "$INITIAL_DND"

echo "Evidence: $EVIDENCE_DIR"
```

## Gotchas

### Daemon Registration Race

**Issue**: If Noctalia starts after another notification daemon (e.g., `mako`, `dunst`), the D-Bus name `org.freedesktop.Notifications` may already be claimed, causing Noctalia's daemon to fail silently.

**Detection**:

```bash
# Check which process owns the notification name
busctl --user status org.freedesktop.Notifications

# Expected output includes:
# OwnerUID=1000
# PID=<noctalia-pid>

# If owned by another process:
# PID=<other-daemon-pid>
```

**Resolution**: Stop competing daemons before starting Noctalia:

```bash
# Kill mako
pkill mako

# Kill dunst
pkill dunst

# Restart Noctalia
pkill noctalia
noctalia --daemon
```

**Verification**: Tests should verify Noctalia owns the name before sending notifications.

### Toast Timing and Timeout

**Default behavior**: Toasts display for 5 seconds (configurable) then auto-dismiss to history. Critical-urgency notifications may persist longer or require explicit dismiss.

**Timing consideration**: Test scripts that send a notification and immediately check state may race with the toast display. Add 0.5–1s delay after `notify-send`.

**Verification**:

```bash
# Send notification
notify-send "Test" "Body"

# Immediate check (may miss toast)
noctalia msg status | jq .notifications.active  # May be empty

# Wait for toast
sleep 0.5

# Check again
noctalia msg status | jq .notifications.active  # Should show notification

# Wait for timeout
sleep 5

# Toast should have dismissed
noctalia msg status | jq .notifications.active  # Empty again
```

### History Persistence

Notification history is **in-memory only** by default. It does not persist across Noctalia restarts unless persistence is configured:

```toml
[notification]
enable_history_persistence = true
history_max_age_days = 7
```

**Test scope**: Verification assumes in-memory history. Persistence tests would require restarting Noctalia and checking history survival.

### DND Bypass for Critical Notifications

**Feature**: Critical-urgency notifications may bypass DND and show toasts even when DND is enabled (configurable with `notification.dnd_allow_critical`).

**Test scenario**:

```bash
# Enable DND
noctalia msg notification-dnd-set on

# Send critical notification
notify-send -u critical "Urgent" "This may bypass DND"

# Expectation depends on config:
# - If dnd_allow_critical=true: Toast appears
# - If dnd_allow_critical=false: Toast suppressed (default)
```

**Verification**: Tests should check config or document expected behavior for both modes.

### Notification Actions

**Standard**: `notify-send` can specify actions (buttons) that invoke callbacks:

```bash
notify-send --action="ok=OK" --action="cancel=Cancel" "Action Test" "Click a button"
```

**Limitation**: `notify-send` does not wait for action callbacks (it's a send-and-forget CLI). Testing action invocation requires:

1. A long-running app that listens for action callbacks
2. D-Bus introspection to capture `ActionInvoked` signals
3. Manual clicking (not automatable)

**Verification scope**: Tests confirm Noctalia daemon receives and records notifications. Action handling requires manual or compositor-specific UI testing.

### Notification Filtering

**Config option**: `notification.block_list` and `notification.allow_list` control which app-ids can send notifications.

**Example**:

```toml
[notification]
block_list = ["Spotify", "Discord"]
```

**Verification**: Sending notifications from blocked apps should result in no toast and no history entry:

```bash
# Send from blocked app (requires spoofing app-id, not trivial with notify-send)
# notify-send alone does not set app-id reliably

# Workaround: Use gdbus directly
gdbus call --session \
  --dest org.freedesktop.Notifications \
  --object-path /org/freedesktop/Notifications \
  --method org.freedesktop.Notifications.Notify \
  "Spotify" 0 "" "Now Playing" "Blocked notification" [] {} 5000
```

**Complexity**: App-id filtering tests require D-Bus API calls; `notify-send` is insufficient.

### Clear History Confirmation

**UI behavior**: `notification-clear-history` IPC command may prompt for confirmation if `notification.confirm_clear_history = true` (default).

**Headless issue**: Confirmation dialogs cannot be automated without compositor input simulation.

**Test workaround**: Set `confirm_clear_history = false` in test config or accept INCONCLUSIVE for full verification.
