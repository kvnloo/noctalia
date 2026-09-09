# Noctalia Verification Skill

Comprehensive verification infrastructure for the Noctalia Wayland desktop shell.

## Quick Links

- **[SKILL.md](SKILL.md)** — Full documentation
- **[features/](features/)** — Feature test scenarios
- **[features/README.md](features/README.md)** — Feature index

## What's Included

### Core Scripts
- **`doctor.sh`** — Pre-flight environment checks (build, deps, compositor, config)
- **`launch.sh`** — Start Noctalia in test mode
- **`drive.sh`** — Execute feature scenarios via IPC
- **`snapshot.sh`** — Capture evidence (screenshots, logs, state)
- **`cleanup.sh`** — Tear down test environment

### Feature Test Scenarios
- **Bar** — Visibility, widgets, multi-monitor
- **Control Center** — Panels, quick settings, network/Bluetooth
- **Notifications** — Toasts, history, urgency, DND
- **Wallpaper** — Picker, multi-monitor, automation
- **Launcher** — Search, calculator, emoji, session actions

## Quick Start

### With Compositor (Local/GUI)
```bash
cd /workspace

# Check environment
.cursor/skills/verify-noctalia/doctor.sh

# Launch Noctalia
.cursor/skills/verify-noctalia/launch.sh --daemon

# Test a feature
.cursor/skills/verify-noctalia/drive.sh bar --action=toggle --id=main

# Capture evidence
.cursor/skills/verify-noctalia/snapshot.sh bar-toggle

# Clean up
.cursor/skills/verify-noctalia/cleanup.sh
```

### Without Compositor (Cloud VM)
```bash
# Dry-run mode validates what it can
.cursor/skills/verify-noctalia/doctor.sh --dry-run
# Exit code 2 (warnings): compositor unavailable but config/build checks pass
```

## Use Cases

1. **Local Development** — Verify changes work end-to-end
2. **Pre-commit Testing** — Smoke test before push
3. **Regression Testing** — Automated feature verification
4. **Bug Reproduction** — Capture evidence for issues
5. **CI/CD** — Automated verification pipelines

## Philosophy

**Verification as Infrastructure** (Build the Lever):
- **Doctor** catches env issues early
- **Drive** automates manual testing
- **Evidence** makes proof portable
- **Cleanup** keeps runs isolated
- **Features** document expected behavior

Result: tight iteration loops, reproducible failures, confident deploys.

## Examples

### Verify Bar Toggle (Fail→Pass)
```bash
# On broken branch
./doctor.sh && ./launch.sh --daemon
./drive.sh bar --action=toggle --id=main
./snapshot.sh bar-broken  # Capture failure
./cleanup.sh

# Apply fix, rebuild
git checkout fix-branch && just build

# Re-test
./launch.sh --daemon
./drive.sh bar --action=toggle --id=main
./snapshot.sh bar-fixed  # Capture success
./cleanup.sh

# Compare evidence
diff /tmp/noctalia-evidence/*bar-broken /tmp/noctalia-evidence/*bar-fixed
```

### Automated Smoke Test
```bash
#!/bin/bash
for feature in bar notifications launcher; do
    ./drive.sh $feature --smoke-test || exit 1
done
```

## Cloud VM Limitations

On VMs without Wayland/X11:
- Full runtime testing **INCONCLUSIVE** (no compositor)
- Doctor validates: build, config, IPC schema, CLI
- Skill still useful for local dev, CI with compositor

## Status

**READY** — All core scripts and feature documentation complete.

**Proven**: Doctor runs on cloud VM in dry-run mode (see [proof/doctor-dry-run.txt](proof/doctor-dry-run.txt))

**Next**: Test on local machine with compositor for full runtime verification.

## License

MIT (same as Noctalia)
