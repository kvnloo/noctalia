# Noctalia Feature Test Scenarios

This directory contains detailed test scenarios for verifying Noctalia features.

## Feature Index

1. **[bar.md](bar.md)** — Bar visibility, widgets, multi-monitor configuration
2. **[control-center.md](control-center.md)** — Control center panels, quick settings, network/bluetooth
3. **[notifications.md](notifications.md)** — Notification toasts, history, urgency levels, filtering
4. **[wallpaper.md](wallpaper.md)** — Wallpaper picker, multi-monitor setup, automation
5. **[launcher.md](launcher.md)** — Launcher search, app launch, calculator, emoji picker

## How to Use

Each feature file documents:
- **Commands**: IPC commands to exercise the feature
- **Expected Behavior**: Observable UI changes, state transitions
- **Evidence**: Screenshots, logs, state dumps to capture as proof
- **Failure Modes**: Common issues and how to diagnose

### Running a Feature Test

```bash
# From repository root
cd /workspace

# 1. Ensure Noctalia is running
.cursor/skills/verify-noctalia/launch.sh --daemon

# 2. Execute feature test
.cursor/skills/verify-noctalia/drive.sh <feature-name>

# 3. Capture evidence
.cursor/skills/verify-noctalia/snapshot.sh <feature-name>

# 4. Cleanup
.cursor/skills/verify-noctalia/cleanup.sh
```

### Example: Testing Bar Feature

```bash
.cursor/skills/verify-noctalia/launch.sh --daemon
.cursor/skills/verify-noctalia/drive.sh bar --action=toggle --id=main
.cursor/skills/verify-noctalia/snapshot.sh bar-toggle
.cursor/skills/verify-noctalia/cleanup.sh
```

## Adding New Features

1. Create `new-feature.md` in this directory
2. Follow the template structure (see existing files)
3. Update this README index
4. Add support in `drive.sh` script

## Feature Template Structure

```markdown
# Feature Name

## Description
What this feature does in Noctalia.

## IPC Commands
Commands to drive the feature via `noctalia msg`.

## Test Scenarios
Step-by-step test cases with expected outcomes.

## Evidence
What artifacts to capture (screenshots, logs, state).

## Common Issues
Known failure modes and diagnostics.
```

## CI Integration

These feature files serve as:
- Manual testing guides for developers
- Automated test scenario definitions for CI
- Documentation of expected behavior
- Regression test specifications

For automated CI testing, wrap scenarios in test harness scripts that parse the commands and validate expected outcomes.
