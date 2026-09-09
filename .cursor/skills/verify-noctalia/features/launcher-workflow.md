# Launcher Workflow

Verification of the launcher panel: open, search, selection, and providers (apps, emoji, calculator, sessions).

## Sub-features

1. **Open launcher**: Panel appears with search box focused
2. **App search**: Desktop entry filtering by name/description/keywords
3. **Emoji search**: `:emoji-name` or keyword matching
4. **Calculator**: Math expression evaluation (e.g., `2+2`, `sqrt(16)`)
5. **Session actions**: Lock, logout, suspend, reboot, shutdown
6. **Window switcher**: Recent window provider
7. **Plugin providers**: User-installed launcher extensions

## How to get to it (user POV)

### Opening

- **Keyboard**: Super key (configurable)
- **IPC**: `noctalia msg panel-open launcher`
- **Bar widget**: Click launcher widget
- **Screen corner**: If configured in hot-corners

### Searching

1. Launcher opens with empty query
2. Start typing: results filter dynamically
3. Arrow keys or mouse navigate results
4. Enter executes selection
5. Escape closes launcher

### Provider-Specific Queries

```
# App search (default)
firefox
term
code

# Emoji search (prefix with : or /emo)
:smile
:rocket
/emo heart

# Calculator (prefix with = or math expression)
=2+2
sqrt(16)
5 * 8

# Session actions (prefix with /)
/lock
/suspend
/logout

# Window switcher (recent windows)
(automatically shown if recent windows exist)
```

## Driving it with control-noctalia

```bash
# Open launcher
./control-noctalia open-panel launcher

# Verify launcher is active
PANEL=$(noctalia msg status | jq -r '.panel // "none"')
[[ "$PANEL" == "launcher" ]] && echo "✓ Launcher open" || echo "✗ Panel: $PANEL"

# Close launcher
noctalia msg panel-close

# Verify closed
PANEL=$(noctalia msg status | jq -r '.panel // "none"')
[[ "$PANEL" == "none" ]] && echo "✓ Launcher closed" || echo "✗ Panel: $PANEL"
```

### Automated Test (Open/Close)

```bash
#!/usr/bin/env bash
# Test: launcher-open-close

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SKILL_DIR/test-helpers.sh"

TEST_NAME="launcher-workflow"
setup_test "$TEST_NAME"

log "Opening launcher..."
noctalia msg panel-open launcher > "$EVIDENCE_DIR/open.txt"
sleep 0.3

# Verify open
STATUS=$(noctalia msg status)
PANEL=$(echo "$STATUS" | jq -r '.panel // "none"')

if [[ "$PANEL" != "launcher" ]]; then
  fail "Expected panel=launcher, got: $PANEL"
fi

log "Launcher open, closing..."
noctalia msg panel-close > "$EVIDENCE_DIR/close.txt"
sleep 0.3

# Verify closed
STATUS=$(noctalia msg status)
PANEL=$(echo "$STATUS" | jq -r '.panel // "none"')

if [[ "$PANEL" != "none" ]]; then
  fail "Expected panel=none, got: $PANEL"
fi

pass "Launcher open/close cycle complete"
```

## Gotchas

### Keyboard Input Simulation

**Challenge**: Verifying search filtering and result selection requires sending keyboard input to the launcher panel. This needs:

- **Wayland virtual keyboard protocol** (`zwp_virtual_keyboard_v1`)
- **Tool**: `wtype`, `ydotool`, or compositor-specific input injection

**Limitation on cloud VM**: Virtual keyboard requires compositor access. Headless verification can only test open/close, not search functionality.

**Example with wtype**:

```bash
# Open launcher
noctalia msg panel-open launcher
sleep 0.3

# Type "firefox" (requires wtype or ydotool)
if command -v wtype &>/dev/null; then
  wtype "firefox"
  sleep 0.5
  
  # Press Enter to launch (not verifiable without window spawn monitoring)
  wtype -k Return
else
  echo "⚠ wtype not available, cannot simulate typing"
fi
```

**Verification scope**: Without input simulation, tests confirm launcher opens/closes but cannot verify search results.

### Provider Priority

When multiple providers match a query, results are interleaved by provider priority (configurable):

1. Apps (desktop entries)
2. Emoji
3. Calculator
4. Sessions
5. Plugin providers

**Conflict example**: Query "term" matches both:
- App provider: "Terminal" (desktop entry)
- Session provider: `:term` (if user typed `:term` explicitly)

Launcher shows app first unless user includes provider prefix.

### Calculator Dependencies

Calculator results require `libqalculate` integration. If `libqalculate` is unavailable (build without `-Dqalculate=enabled`):

- Calculator provider is disabled
- Math queries show no results

**Verification**: Check build flags or attempt calculator query:

```bash
# Open launcher
noctalia msg panel-open launcher

# Attempt calculator query (requires input simulation)
# Expected: Result shows "4" for "=2+2"
# If calculator disabled: No results
```

**Build flag check**:

```bash
# Check if noctalia was built with qalculate
ldd $(which noctalia) | grep qalculate || echo "qalculate not linked"
```

### Emoji Database

Emoji search depends on `assets/emoji.json` (shipped with Noctalia). If the asset is missing or corrupted:

- Emoji provider returns no results
- `:smile` queries fail

**Verification**:

```bash
# Locate emoji database
EMOJI_DB=$(find /usr/share/noctalia -name emoji.json 2>/dev/null || echo "Not found")
[[ -f "$EMOJI_DB" ]] && echo "✓ Emoji DB: $EMOJI_DB" || echo "✗ Emoji DB missing"
```

### Session Actions Permissions

Session actions (logout, reboot, shutdown) require:

- **logind** integration (systemd-logind or elogind)
- **Polkit** authorization (some actions prompt for password)

**Verification limitation**: Cannot automate password prompts. Tests confirm launcher shows session actions but cannot trigger them end-to-end.

**Safe verification**:

```bash
# Test session action that doesn't require password (lock)
noctalia msg panel-open launcher

# Simulate typing "/lock" (if input available)
# Expected: Screen lock activates

# Alternative: Direct IPC
noctalia msg session lock
```

### Plugin Providers

User-installed plugins can add launcher providers (e.g., notes search, project switcher). Plugin state is:

- **Enabled**: Provider shows in launcher results
- **Disabled**: Provider hidden

**Verification**: Plugin providers are outside core scope. Tests focus on built-in providers (apps, emoji, calculator, sessions).

### Window Switcher Mode

If `launcher.show_windows` is enabled in config, the launcher also shows recent windows as selectable entries. This is compositor-dependent:

- **Hyprland/Sway**: Requires `foreign-toplevel` protocol support
- **Niri**: Native workspace API
- **Minimal compositors**: May not provide window list

**Verification**: Window switcher results depend on active windows and compositor capabilities. Tests should not assume window list availability.
