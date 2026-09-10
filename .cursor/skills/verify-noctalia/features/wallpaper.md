# Wallpaper Feature

## Description

Noctalia manages wallpapers via native Wayland background layer-shell surfaces. Supports per-monitor wallpapers, automation (time-based, random, slideshow), and integration with wallpaper picker panel.

## Configuration

Wallpaper settings in `[wallpaper]` and `[wallpaper.default]`:
```toml
[wallpaper]
enabled = true

[wallpaper.default]
path = "~/Pictures/wallpaper.png"
mode = "fill"  # fill | fit | stretch | center | tile
output = ""    # empty = all outputs, or specific output name

[wallpaper.automation]
enabled = false
mode = "time"  # time | random | slideshow
interval = 3600  # seconds between changes (for random/slideshow)
paths = [
  "~/Pictures/wallpapers/morning.png",
  "~/Pictures/wallpapers/evening.png",
]
```

## IPC Commands

### Set Wallpaper
```bash
noctalia msg wallpaper-set <path> [output]
```
Sets wallpaper to the specified image path, optionally for a specific output.

Example:
```bash
noctalia msg wallpaper-set ~/Pictures/sunset.png
noctalia msg wallpaper-set ~/Pictures/monitor1.png HDMI-A-1
```

### Next Wallpaper (Automation)
```bash
noctalia msg wallpaper-next
```
Advances to the next wallpaper in automation sequence (if enabled).

### Previous Wallpaper (Automation)
```bash
noctalia msg wallpaper-prev
```
Returns to the previous wallpaper in automation sequence.

### Open Wallpaper Picker
```bash
noctalia msg panel-open wallpaper
```
Opens the wallpaper picker panel UI.

### Reload Wallpaper
```bash
noctalia msg wallpaper-reload
```
Reloads wallpaper from config (useful after config change).

## Test Scenarios

### Scenario 1: Set Static Wallpaper
**Goal**: Verify wallpaper changes via IPC command.

**Steps**:
1. Launch Noctalia with default wallpaper
2. Capture screenshot of desktop background
3. Place test image at `/tmp/test-wallpaper.png`
4. Execute `noctalia msg wallpaper-set /tmp/test-wallpaper.png`
5. Wait 500ms for surface update
6. Capture screenshot showing new wallpaper

**Expected**:
- Wallpaper surface updates immediately
- Image scaled according to `mode` setting
- No flicker or black screen during transition

**Evidence**:
- Before/after screenshots
- IPC command log
- Shell wallpaper surface logs

### Scenario 2: Per-Monitor Wallpapers
**Goal**: Verify different wallpapers on multiple monitors.

**Steps**:
1. Configure multi-monitor setup
2. Set wallpaper for first output: `noctalia msg wallpaper-set ~/wall1.png HDMI-A-1`
3. Set wallpaper for second output: `noctalia msg wallpaper-set ~/wall2.png DP-1`
4. Capture multi-monitor screenshot
5. Verify each monitor shows correct wallpaper

**Expected**:
- Each output shows its configured wallpaper
- Wallpapers scale independently per output resolution
- Hot-plugging monitor applies wallpaper automatically

**Evidence**:
- Multi-monitor screenshot
- Config showing per-output wallpaper paths
- Output names from `hyprctl monitors` or equivalent

### Scenario 3: Wallpaper Modes
**Goal**: Verify scaling modes (fill, fit, stretch, center, tile).

**Steps**:
For each mode:
1. Edit config: `mode = "<mode>"`
2. Reload: `noctalia msg wallpaper-reload`
3. Capture screenshot
4. Verify scaling behavior matches mode

**Expected**:
- `fill`: image fills screen, crops to aspect ratio
- `fit`: image fits within screen, letterboxed if needed
- `stretch`: image stretched to fill, ignoring aspect ratio
- `center`: image centered, no scaling
- `tile`: image repeated to fill screen

**Evidence**:
- Screenshot per mode
- Config snippet showing mode setting

### Scenario 4: Wallpaper Automation
**Goal**: Verify time-based or random wallpaper changes.

**Steps**:
1. Configure automation with `mode = "random"` and short interval (e.g., 10s for testing)
2. Launch Noctalia
3. Capture screenshot of initial wallpaper
4. Wait for interval
5. Capture screenshot after auto-change
6. Execute `noctalia msg wallpaper-next` manually
7. Verify wallpaper advances

**Expected**:
- Wallpaper changes automatically at interval
- Manual `wallpaper-next`/`wallpaper-prev` works
- Rotation stays within configured `paths` list

**Evidence**:
- Time-series screenshots showing wallpaper changes
- Automation config snippet
- Shell logs showing wallpaper change events

### Scenario 5: Wallpaper Picker Panel
**Goal**: Verify picker UI allows browsing and selecting wallpapers.

**Steps**:
1. Open picker: `noctalia msg panel-open wallpaper`
2. Browse available wallpapers
3. Click on wallpaper thumbnail
4. Verify wallpaper applies immediately
5. Close picker

**Expected**:
- Picker shows thumbnails of wallpapers in configured directories
- Clicking thumbnail applies wallpaper
- Picker supports searching/filtering (if implemented)

**Evidence**:
- Screenshot of wallpaper picker panel
- Screenshot of desktop after picker selection

### Scenario 6: Image Format Support
**Goal**: Verify supported image formats (PNG, JPG, WebP, JPEG XL, SVG).

**Steps**:
1. Test each format:
   - `noctalia msg wallpaper-set test.png`
   - `noctalia msg wallpaper-set test.jpg`
   - `noctalia msg wallpaper-set test.webp`
   - `noctalia msg wallpaper-set test.jxl`
   - `noctalia msg wallpaper-set test.svg`
2. Verify each loads and displays correctly

**Expected**:
- All supported formats load without error
- SVG scales smoothly to screen resolution
- WebP/JPEG XL decode correctly

**Evidence**:
- Screenshot per format
- Shell logs confirming format decode

## Common Issues

### Wallpaper Not Appearing
- **Cause**: Compositor doesn't support background layer
- **Diagnosis**: Check compositor logs for layer-shell errors
- **Fix**: Use compositor with full layer-shell support

### Image Format Unsupported
- **Cause**: Missing decoder library (e.g., libjxl for JPEG XL)
- **Diagnosis**: Check build deps, shell logs for decoder errors
- **Fix**: Install missing image libraries, rebuild if needed

### Wallpaper Flickers on Change
- **Cause**: Double-buffering or surface swap timing issue
- **Diagnosis**: Check shell logs, compositor vsync settings
- **Fix**: Enable vsync, check Wayland surface commit logic

### Automation Not Triggering
- **Cause**: Automation disabled or timer not running
- **Diagnosis**: Check `[wallpaper.automation]` config, shell timer logs
- **Fix**: Enable automation, verify interval > 0

### Wrong Wallpaper on Monitor
- **Cause**: Output name mismatch or hot-plug race
- **Diagnosis**: Check output names in `hyprctl monitors`, config output names
- **Fix**: Use correct output names, reload wallpaper after hot-plug

## Verification Checklist

- [ ] Static wallpaper sets via IPC
- [ ] Per-monitor wallpapers work independently
- [ ] All scaling modes (fill, fit, stretch, center, tile) work
- [ ] Automation changes wallpaper at interval
- [ ] Wallpaper picker opens and applies selections
- [ ] Supported image formats load (PNG, JPG, WebP, JPEG XL, SVG)
- [ ] No flicker during wallpaper change
- [ ] Hot-plug monitor applies wallpaper correctly

## Evidence Artifacts

Capture:
- **Screenshots**: Wallpaper before/after change, each scaling mode, multi-monitor setup, picker panel
- **Logs**: Wallpaper set commands, automation change events, image decoder logs
- **Config**: `[wallpaper]` and `[wallpaper.automation]` sections
- **Images**: Sample wallpaper files used in testing (reference for formats)
