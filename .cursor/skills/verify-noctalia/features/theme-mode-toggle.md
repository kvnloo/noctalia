# Theme Mode Toggle

Dark ↔ light theme mode transitions via IPC. Portal/GTK sync is optional observation, never a hard pass gate.

## Sub-features

- `toggle-dark-light` — `theme-mode-toggle` flips resolved dark ↔ light only
- `get-resolved` — `theme-mode-get` prints resolved `light` or `dark` (never `auto`)
- `set-persist` — `theme-mode-set dark|light|auto` writes `[theme].mode` and reloads
- `restore-hazard` — restoring with resolved get after `auto` **loses** `auto`

## How to get to it (user POV)

- Control center → Appearance → Theme mode
- Bar `theme_mode` widget
- IPC (preferred for agents):

```bash
noctalia msg theme-mode-get
noctalia msg theme-mode-toggle
noctalia msg theme-mode-set dark
noctalia msg theme-mode-set light
noctalia msg theme-mode-set auto
```

## Driving it with control-noctalia

Preconditions: compositor + Noctalia IPC responsive. **gtk-theme / gsettings are not required** for PASS.

```bash
SKILL=.cursor/skills/verify-noctalia
EVIDENCE_DIR="/tmp/noctalia-verify-evidence/theme-toggle-$(date +%s)"
# mkdir BEFORE any tee/redirect — missing dir → EXIT 1 under set -e / pipefail
mkdir -p "$EVIDENCE_DIR" || exit 1

# theme-mode-get → resolved light|dark only (even when configured mode is auto)
INITIAL_RESOLVED=$("$SKILL/control-noctalia" get-theme-mode | tee "$EVIDENCE_DIR/initial-resolved.txt")
echo "$INITIAL_RESOLVED" | grep -Eq '^(light|dark)$' || {
  echo "FAIL: get-theme-mode expected light|dark, got: $INITIAL_RESOLVED" | tee "$EVIDENCE_DIR/result.txt"
  exit 1
}

"$SKILL/control-noctalia" toggle-theme-mode | tee "$EVIDENCE_DIR/toggle-output.txt"
AFTER=$("$SKILL/control-noctalia" get-theme-mode | tee "$EVIDENCE_DIR/after-resolved.txt")

if [[ "$AFTER" == "$INITIAL_RESOLVED" ]]; then
  echo "FAIL: resolved mode unchanged ($INITIAL_RESOLVED)" | tee "$EVIDENCE_DIR/result.txt"
  exit 1
fi
if ! echo "$AFTER" | grep -Eq '^(light|dark)$'; then
  echo "FAIL: after toggle not light|dark: $AFTER" | tee "$EVIDENCE_DIR/result.txt"
  exit 1
fi

echo "PASS: $INITIAL_RESOLVED → $AFTER" | tee "$EVIDENCE_DIR/result.txt"

# Restore: setting the resolved value does NOT restore auto.
# If the session started in auto, theme-mode-set "$INITIAL_RESOLVED" permanently leaves auto.
"$SKILL/control-noctalia" set-theme-mode "$INITIAL_RESOLVED" || true
echo "Restored resolved mode=$INITIAL_RESOLVED (auto NOT restored if it was configured)" | tee -a "$EVIDENCE_DIR/test.log"

# Preferred one-shot
"$SKILL/control-noctalia" feature theme-mode-toggle
```

**Pass gate**: resolved IPC mode changed dark ↔ light. Portal `color-scheme` / `gtk-theme` deltas are optional notes only.

## Gotchas

- **`theme-mode-get` is resolved** — prints `dark` or `light` from `[theme].mode` or the location schedule when mode is `auto`. It never prints `auto`.
- **`theme-mode-toggle` is dark ↔ light only** — same as the bar control when mode is not `auto`. It does **not** cycle `dark → light → auto`.
- **Restore after auto loses auto** — capturing only `theme-mode-get` then `theme-mode-set` that value replaces `auto` with a concrete mode. Persist configured mode from settings if you must restore `auto`.
- **No gtk-theme required** — do not FAIL when gtk-theme or color-scheme is unchanged/unavailable.
- Portal timing (PER-328 / #4181) can reorder gtk-theme vs color-scheme on Hyprland; treat portal as soft signal only.
