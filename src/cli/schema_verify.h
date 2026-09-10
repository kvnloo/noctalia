#pragma once

#include "cli/schema.h"

#include <array>
#include <string_view>

namespace noctalia::cli {

  inline constexpr std::array<std::string_view, 6> kVerifyFeatureChoices{
      "theme-mode-toggle",
      "panel-toggle",
      "launcher-workflow",
      "notification-flow",
      "bar-widgets",
      "all",
  };

  inline constexpr std::array kVerifyDoctorFlags{
      Flag{"--verbose", "-v", {}, "Show detailed diagnostics", {}, {}, false, false},
  };

  inline constexpr std::array kVerifyFeaturePositionals{
      Positional{"feature", "Feature name to verify", kVerifyFeatureChoices, true, false, false},
  };

  inline constexpr std::array kVerifyFeatureFlags{
      Flag{"--evidence-dir", {}, "PATH", "Custom evidence directory path", {}, {}, false, false},
      Flag{"--no-cleanup", {}, {}, "Skip cleanup after test", {}, {}, false, false},
  };

  inline constexpr std::array kVerifySubcommands{
      Command{
          "doctor",
          "Run environment health check",
          "Verify compositor, IPC socket, theme tools, and Noctalia responsiveness.\n\n"
          "Exit codes:\n"
          "  0 - PASS (all checks green)\n"
          "  1 - FAIL (Noctalia not running or unresponsive)\n"
          "  2 - INCONCLUSIVE (compositor missing, headless environment)",
          {},
          kVerifyDoctorFlags,
          {},
          {},
          false,
      },
      Command{
          "feature",
          "Run feature-specific verification",
          "Execute automated test for a specific Noctalia feature.\n\n"
          "Available features:\n"
          "  theme-mode-toggle   - Dark/light mode transitions and portal sync\n"
          "  panel-toggle        - Panel open/close/toggle with context\n"
          "  launcher-workflow   - Launcher panel open/close\n"
          "  notification-flow   - Notification daemon, DND, history\n"
          "  bar-widgets         - Widget presence and data updates\n"
          "  all                 - Run all features sequentially\n\n"
          "Evidence is saved to /tmp/noctalia-verify-evidence/ by default.",
          {},
          kVerifyFeatureFlags,
          kVerifyFeaturePositionals,
          {},
          false,
      },
      Command{
          "list",
          "List available verification features",
          "Display all features that can be verified with the 'feature' subcommand.",
          {},
          {},
          {},
          {},
          false,
      },
  };

  inline constexpr Command kVerifyCmd{
      "verify",
      "Verify Noctalia functionality through automated testing",
      "Run health checks and feature-specific verification tests.\n\n"
      "This command provides systematic validation of Noctalia components\n"
      "including IPC, theme system, panels, notifications, and bar widgets.\n\n"
      "Start with 'noctalia verify doctor' to check environment readiness.",
      {},
      {},
      {},
      kVerifySubcommands,
      false,
  };

  static_assert(validateCommand(kVerifyCmd));

} // namespace noctalia::cli
