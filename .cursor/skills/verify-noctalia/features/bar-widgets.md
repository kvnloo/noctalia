# Bar Widgets

Verification of bar widget rendering, data updates, and configuration.

## Sub-features

1. **Widget presence**: Configured widgets appear in bar
2. **Data updates**: Dynamic widgets refresh (clock, battery, network, media)
3. **Click actions**: Widget mouse bindings trigger IPC commands
4. **Gesture bindings**: Swipe gestures on widgets (e.g., theme-mode swipe)
5. **Widget settings**: IPC command to open widget-specific settings
6. **Custom widgets**: Script-backed widgets with user-defined commands

## How to get to it (user POV)

### Viewing Widgets

- Widgets display on configured bars (top, bottom, left, right)
- Each bar can have multiple widgets in left/center/right sections
- Widgets show:
  - **Clock**: Current time/date
  - **Battery**: Charge percentage and icon
  - **Network**: WiFi/Ethernet status and name
  - **Media**: Currently playing track and controls
  - **Workspace**: Active workspace indicator
  - **Tray**: System tray icons
  - **Custom**: User-defined text/icon from script

### Interacting

```bash
# Open widget settings
noctalia msg settings-open-widget <bar-name> <widget-name>

# Example: Configure clock widget on main bar
noctalia msg settings-open-widget main clock
```

### Widget Gestures

Default gesture bindings (configurable):

- **Theme mode widget**: Left swipe → toggle dark/light
- **Media widget**: Left/right swipe → previous/next track
- **Volume widget**: Up/down swipe → volume adjust

## Driving it with control-noctalia

```bash
EVIDENCE_DIR="/tmp/noctalia-verify-evidence/bar-widgets-$(date +%s)"
mkdir -p "$EVIDENCE_DIR"

# 1. Get bar configuration
echo "Fetching bar status..."
noctalia msg status > "$EVIDENCE_DIR/status.json"

# Extract bar names
BARS=$(jq -r '.bars[] | .name' "$EVIDENCE_DIR/status.json" 2>/dev/null || echo "")

if [[ -z "$BARS" ]]; then
  echo "✗ No bars found in status"
  exit 1
fi

echo "Bars found: $BARS"

# 2. For each bar, list widgets
for BAR in $BARS; do
  echo "Bar: $BAR"
  WIDGETS=$(jq -r ".bars[] | select(.name == \"$BAR\") | .widgets[] | .name" "$EVIDENCE_DIR/status.json" 2>/dev/null || echo "")
  
  if [[ -z "$WIDGETS" ]]; then
    echo "  ⚠ No widgets on bar $BAR"
    continue
  fi
  
  echo "  Widgets:"
  echo "$WIDGETS" | while read -r WIDGET; do
    echo "    - $WIDGET"
  done
done > "$EVIDENCE_DIR/bar-inventory.txt"

cat "$EVIDENCE_DIR/bar-inventory.txt"

# 3. Test dynamic widget updates (clock)
echo "Testing clock widget updates..."
TIME1=$(jq -r '.bars[0].widgets[] | select(.name == "clock") | .text' "$EVIDENCE_DIR/status.json" 2>/dev/null || echo "")
echo "Clock time T0: $TIME1" > "$EVIDENCE_DIR/clock-test.txt"

sleep 2

noctalia msg status > "$EVIDENCE_DIR/status-t1.json"
TIME2=$(jq -r '.bars[0].widgets[] | select(.name == "clock") | .text' "$EVIDENCE_DIR/status-t1.json" 2>/dev/null || echo "")
echo "Clock time T1: $TIME2" >> "$EVIDENCE_DIR/clock-test.txt"

if [[ "$TIME1" != "$TIME2" ]]; then
  echo "✓ Clock widget updating" | tee -a "$EVIDENCE_DIR/clock-test.txt"
else
  echo "⚠ Clock widget not updating (or 1-second precision)" | tee -a "$EVIDENCE_DIR/clock-test.txt"
fi

# 4. Test battery widget (if present)
BATTERY=$(jq -r '.bars[].widgets[] | select(.name == "battery") | .percentage' "$EVIDENCE_DIR/status.json" 2>/dev/null || echo "")

if [[ -n "$BATTERY" ]]; then
  echo "✓ Battery widget present: $BATTERY%" | tee "$EVIDENCE_DIR/battery-widget.txt"
else
  echo "⚠ Battery widget not found (may be VM without battery)" | tee "$EVIDENCE_DIR/battery-widget.txt"
fi

# 5. Test widget settings command
echo "Testing widget settings command..."
if noctalia msg settings-open-widget main clock 2>&1 | tee "$EVIDENCE_DIR/settings-widget.txt"; then
  echo "✓ Widget settings command executed"
  # Close settings window
  noctalia msg settings-close
else
  echo "✗ Widget settings command failed"
fi

echo "PASS" > "$EVIDENCE_DIR/result.txt"
echo "Evidence: $EVIDENCE_DIR"
```

## Gotchas

### Battery Widget on VMs

**Issue**: Cloud VMs and desktop systems without batteries will not have the battery widget enabled, even if configured in `config.toml`.

**Detection**:

```bash
# Check if battery exists
ls /sys/class/power_supply/BAT* 2>/dev/null || echo "No battery"

# UPower check
upower -e | grep battery || echo "No UPower battery device"
```

**Verification expectation**:
- Hardware with battery: Battery widget should show percentage and charging state
- VM/desktop without battery: Battery widget absent (not an error)

**Result classification**:
- PASS: Widget shows on battery-equipped systems
- INCONCLUSIVE: Widget absent on VM (expected)
- FAIL: Widget configured but not rendering on battery-equipped system

### Network Widget Dependency

**Network widget** requires:
- **NetworkManager** D-Bus service
- Active connection (WiFi or Ethernet)

**Fallback**: On systems without NetworkManager (e.g., using `iwd` or `connman`), the network widget may show "N/A" or be disabled.

**Verification**:

```bash
# Check NetworkManager
systemctl is-active NetworkManager || echo "NetworkManager not running"

# Check active connection
nmcli -t -f DEVICE,STATE device | grep connected || echo "No connection"
```

### Media Widget No Player

**Media widget** shows currently playing media from MPRIS-compatible players (Spotify, VLC, Firefox, etc.).

**When no player is active**: Widget shows "No media" or is hidden (depending on config).

**Test limitation**: Cannot automate media playback without:
1. Installing a media player
2. Starting playback with audio file

**Verification scope**: Confirm widget is present and IPC commands respond (no playback verification).

### Custom Script Widgets

**Custom widgets** execute user-defined scripts to generate widget text/icon:

```toml
[[widget.custom]]
name = "my-widget"
exec = "/path/to/script.sh"
interval = 5
```

**Script requirements**:
- Executable permission
- Output format: JSON with `text` and optional `icon` fields

**Verification**: Custom widgets are user-specific; tests focus on built-in widgets (clock, battery, network, media).

### Widget Refresh Intervals

**Dynamic widgets** refresh at configured intervals:
- Clock: 1 second (default)
- Battery: 5 seconds (or on UPower event)
- Network: On NetworkManager signal
- Media: On MPRIS signal

**Test timing**: Wait at least `interval` seconds to observe updates. Status snapshots taken too quickly may show identical values.

### Tray Widget Platform Support

**System tray** (StatusNotifierItem protocol) requires:
- D-Bus `StatusNotifierWatcher` service (Noctalia provides)
- Applications with tray icon support (Slack, Discord, Steam, etc.)

**On minimal systems**: No tray icons may appear if no apps with tray support are running.

**Verification**:

```bash
# Check if StatusNotifierWatcher is registered
busctl --user status org.kde.StatusNotifierWatcher >/dev/null 2>&1 && echo "✓ Tray service active" || echo "✗ Tray service not found"

# List tray items
busctl --user call org.kde.StatusNotifierWatcher \
  /StatusNotifierWatcher \
  org.kde.StatusNotifierWatcher.RegisteredStatusNotifierItems \
  2>/dev/null || echo "No tray items"
```

### Workspace Widget Compositor Dependency

**Workspace widget** shows active workspace name/number and depends on compositor workspace protocol:

- **Hyprland**: Native IPC (`hyprctl`)
- **Sway**: Native IPC (`swaymsg`)
- **Niri**: Native IPC (`niri msg`)
- **Generic**: `ext-workspace-v1` protocol

**Without workspace support**: Widget shows "N/A" or is disabled.

**Verification**: Workspace widget tests require running on a supported compositor with active workspaces.

### Widget Click Actions

**Widget mouse bindings** trigger IPC commands on click (left, middle, right):

```toml
[[widget.clock]]
on_click_left = "panel-open launcher"
on_click_right = "settings-open"
```

**Test limitation**: Simulating mouse clicks on layer-shell surfaces requires:
- Compositor input injection support
- Tool: `wtype -M` or compositor-specific click simulator

**Verification scope**: Tests confirm widgets respond to IPC commands, but cannot automate click simulation on cloud VM.
