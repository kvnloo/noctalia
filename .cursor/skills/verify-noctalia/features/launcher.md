# Launcher Feature

## Description

The Noctalia launcher is a unified search interface for applications, files, emojis, calculations, sessions, windows, and plugin-provided results. It supports fuzzy search, usage-based sorting, provider prefixes, and keyboard-driven navigation.

## Configuration

Launcher settings in `[shell.launcher]`:
```toml
[shell.launcher]
categories = true                    # show category filters
show_icons = true                    # application icons
show_app_origin_indicator = true     # package origin badges
compact = false                      # compact result rows
app_grid = false                     # grid view for app-only results
sort_by_usage = true                 # usage frequency sorting
pinned = ["firefox", "kitty", "code"] # pinned apps (launcher only)
fetch_exchange_rates = true          # currency conversion data
provider_prefix = "/"                # prefix for provider triggers
auto_paste = "auto"                  # copy result auto-paste behavior

[shell.launcher.providers.calculator]
prefix = "calc"
global = true                        # show in unprefixed search

[shell.launcher.providers.emoji]
prefix = "emo"

[shell.launcher.providers.session]
prefix = "session"
global = false                       # exclude from unprefixed search

[shell.launcher.providers.wallpaper]
prefix = "wall"
```

## IPC Commands

### Open Launcher
```bash
noctalia msg panel-open launcher
```
Opens the launcher panel.

### Close Launcher
```bash
noctalia msg panel-close launcher
```
Closes the launcher panel.

### Toggle Launcher
```bash
noctalia msg panel-toggle launcher
```
Toggles launcher open/closed.

### Launch Application (Direct)
```bash
noctalia msg launch-app <app_id>
```
Launches application by desktop entry ID (e.g., `firefox`).

## Test Scenarios

### Scenario 1: Open and Search Apps
**Goal**: Verify launcher opens and searches installed apps.

**Steps**:
1. Launch Noctalia
2. Execute `noctalia msg panel-open launcher`
3. Type "firef" (partial app name)
4. Verify "Firefox" appears in results
5. Press Enter or click result
6. Verify Firefox launches

**Expected**:
- Launcher opens centered (or as configured)
- Results update as you type (fuzzy match)
- Icons and descriptions shown
- Launching app closes launcher

**Evidence**:
- Screenshot of launcher with search results
- Screenshot after app launch (Firefox open)
- IPC command logs

### Scenario 2: Calculator Provider
**Goal**: Verify inline calculator and unit conversion.

**Steps**:
1. Open launcher
2. Type `/calc 2 + 2`
3. Verify result shows "4"
4. Type `/calc 100 USD to EUR`
5. Verify currency conversion result
6. Press Enter to copy result

**Expected**:
- Calculator evaluates expressions instantly
- Unit conversion works (length, mass, currency)
- Result copied to clipboard on activation

**Evidence**:
- Screenshot of calculator result
- Screenshot of unit conversion result
- Clipboard contents verification

### Scenario 3: Emoji Picker
**Goal**: Verify emoji search and insertion.

**Steps**:
1. Open launcher
2. Type `/emo smile`
3. Verify emoji results (😊, 🙂, etc.)
4. Click or press Enter on emoji
5. Verify emoji copied to clipboard

**Expected**:
- Emoji results match search keywords
- Emoji copied to clipboard
- Auto-paste inserts emoji if enabled

**Evidence**:
- Screenshot of emoji results
- Clipboard verification (emoji character)

### Scenario 4: Session Actions
**Goal**: Verify session commands (logout, restart, shutdown, lock).

**Steps**:
1. Open launcher
2. Type `/session`
3. Verify session actions listed:
   - Lock
   - Logout
   - Restart
   - Shutdown
4. Select "Lock" (do NOT execute shutdown in test!)
5. Verify lock screen activates

**Expected**:
- Session actions appear with correct icons
- Lock action triggers lock screen
- Other actions show confirmation prompts

**Evidence**:
- Screenshot of session provider results
- Screenshot of lock screen (if lock action tested)

### Scenario 5: Window Switcher
**Goal**: Verify window/workspace search.

**Steps**:
1. Open multiple apps (Firefox, terminal, editor)
2. Open launcher
3. Type window title or app name
4. Verify open windows appear in results
5. Select window → verify focus switches

**Expected**:
- Open windows listed in results
- Selecting window switches focus
- Workspaces searchable (if supported)

**Evidence**:
- Screenshot of window results
- Before/after focus screenshots

### Scenario 6: Pinned Apps
**Goal**: Verify pinned apps appear at top.

**Steps**:
1. Configure `pinned = ["firefox", "kitty"]` in config
2. Reload config
3. Open launcher (empty query)
4. Verify pinned apps shown first

**Expected**:
- Pinned apps appear before unpinned
- Pinned order matches config order
- Pinned apps always visible

**Evidence**:
- Screenshot of launcher with pinned apps
- Config snippet showing `pinned` list

### Scenario 7: Usage-Based Sorting
**Goal**: Verify frequently launched apps rank higher.

**Steps**:
1. Enable `sort_by_usage = true`
2. Launch "Firefox" 5 times via launcher
3. Open launcher, type "fi"
4. Verify Firefox appears before other "fi" matches

**Expected**:
- Frequently used apps rank higher
- Usage stats persist across sessions
- Sorting respects fuzzy match quality + usage

**Evidence**:
- Screenshot showing Firefox ranked high
- Usage stats file (if accessible)

### Scenario 8: Provider Prefix
**Goal**: Verify provider trigger prefixes work.

**Steps**:
1. Type `/calc` → calculator results
2. Type `/emo` → emoji results
3. Type `/session` → session actions
4. Type `/wall` → wallpaper results

**Expected**:
- Each prefix activates correct provider
- Providers with `global = true` also appear unprefixed
- Unknown prefixes show no results or suggestions

**Evidence**:
- Screenshots of each provider result set

## Common Issues

### Launcher Won't Open
- **Cause**: Panel surface creation failed
- **Diagnosis**: Check shell logs for layer-shell errors
- **Fix**: Verify compositor supports floating panels

### No Apps Appearing
- **Cause**: Desktop entry scan failed
- **Diagnosis**: Check `~/.local/share/applications/`, `/usr/share/applications/`
- **Fix**: Verify XDG data dirs, rebuild desktop entry cache

### Calculator Not Working
- **Cause**: libqalculate missing or failed to init
- **Diagnosis**: Check build deps, shell logs for qalculate errors
- **Fix**: Install libqalculate, rebuild Noctalia

### Emoji Search Empty
- **Cause**: Emoji data file missing
- **Diagnosis**: Check `assets/emoji.json` exists
- **Fix**: Verify assets installed, reinstall if needed

### Session Actions Unresponsive
- **Cause**: logind/systemd not available
- **Diagnosis**: Check D-Bus logind connection
- **Fix**: Ensure systemd-logind running

## Verification Checklist

- [ ] Launcher opens on command
- [ ] App search returns installed apps
- [ ] Calculator evaluates expressions
- [ ] Unit conversion works
- [ ] Emoji picker returns emojis
- [ ] Session actions listed (lock, logout, shutdown, restart)
- [ ] Window switcher shows open windows
- [ ] Pinned apps appear first
- [ ] Usage-based sorting works
- [ ] Provider prefixes trigger correct providers
- [ ] Auto-paste inserts results (if enabled)
- [ ] No crashes during search/launch

## Evidence Artifacts

Capture:
- **Screenshots**: Launcher main view, app results, calculator, emoji, session, window switcher, pinned apps
- **Logs**: Launcher open/close, search queries, app launch commands
- **Config**: `[shell.launcher]` and provider sections
- **Desktop Entries**: Sample of parsed apps (for debugging)
