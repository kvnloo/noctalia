# Noctalia Feature Map

This directory contains feature-specific verification specifications for Noctalia desktop shell components.

## Feature Inventory

| Feature | Status | Priority | Dependencies |
|---------|--------|----------|--------------|
| theme-mode-toggle | Ready | High | gsettings/dconf, compositor |
| panel-toggle | Ready | High | Running Noctalia instance |
| launcher-workflow | Ready | Medium | compositor, keyboard input simulation |
| notification-flow | Ready | Medium | D-Bus, notification daemon |
| bar-widgets | Ready | Low | Configured bar, widget data sources |

## Feature Status

- **Ready**: Feature file complete, test harness implemented
- **Draft**: Feature file exists, test harness in progress
- **Planned**: Identified but not yet documented

## Testing Strategy

Each feature file follows this structure:

1. **Sub-features**: List of testable behaviors within the feature
2. **How to get to it**: User-visible steps to trigger the feature
3. **Driving it with harness**: Control script commands and IPC calls
4. **Gotchas**: Known issues, timing dependencies, compositor-specific behavior

## Adding New Features

To add a new feature verification:

1. Create `features/<feature-name>.md` following the template
2. Update the inventory table above
3. Implement any feature-specific helpers in the skill directory
4. Add the feature to `noctalia verify list` output

## Cross-Feature Dependencies

- **Theme mode** affects panel appearance, notifications, and bar widgets
- **Panel state** persists across config reloads
- **Compositor integration** determines workspace/output/window APIs available

## Verification Coverage

Current coverage focuses on:
- ✅ IPC command validation
- ✅ Theme system (mode, palette, portal sync)
- ✅ Panel lifecycle (open/toggle/close)
- ⚠️ UI interaction (limited to compositor-provided tools)
- ⚠️ Visual regression (screenshots where available)

Future coverage:
- Notification history and filtering
- Desktop/lockscreen widget editor
- Wallpaper picker and favorites
- Plugin lifecycle
- Template application (KDE color-scheme, Firefox theme)
