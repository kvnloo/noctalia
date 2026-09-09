#include "cli/verify.h"

#include "cli/help.h"
#include "cli/parse.h"
#include "cli/schema_verify.h"
#include "core/files/resource_paths.h"

#include <cstdlib>
#include <filesystem>
#include <print>
#include <string>
#include <string_view>
#include <unistd.h>

namespace noctalia::cli {

  namespace {

    std::filesystem::path skillPath() {
      // Try to locate the verify-noctalia skill directory
      // Priority: .cursor/skills in workspace, then installed location
      
      const char* pwd = std::getenv("PWD");
      if (pwd != nullptr && pwd[0] != '\0') {
        const std::filesystem::path workspaceSkill = 
            std::filesystem::path(pwd) / ".cursor" / "skills" / "verify-noctalia";
        if (std::filesystem::exists(workspaceSkill / "SKILL.md")) {
          return workspaceSkill;
        }
      }
      
      // Try relative to executable
      std::filesystem::path execPath = std::filesystem::read_symlink("/proc/self/exe");
      std::filesystem::path relativeSkill = execPath.parent_path().parent_path() / 
          "share" / "noctalia" / "skills" / "verify-noctalia";
      if (std::filesystem::exists(relativeSkill / "SKILL.md")) {
        return relativeSkill;
      }
      
      return {};
    }

    int runDoctor(const ParsedArgs& args) {
      const std::filesystem::path skill = skillPath();
      if (skill.empty()) {
        std::println(stderr, "error: verify-noctalia skill not found");
        std::println(stderr, "Expected location: .cursor/skills/verify-noctalia/");
        return 1;
      }

      const bool verbose = args.has("--verbose");
      std::string cmd = skill / "control-noctalia";
      cmd += " ping";
      
      if (verbose) {
        std::println("Running doctor check from: {}", skill.string());
      }

      // For now, just run a basic ping test
      // Full doctor implementation would exec a shell script from the skill directory
      const int result = std::system(cmd.c_str());
      if (result == 0) {
        std::println("Doctor check: PASS");
        return 0;
      } else if (WEXITSTATUS(result) == 2) {
        std::println("Doctor check: INCONCLUSIVE (compositor not available)");
        return 2;
      } else {
        std::println("Doctor check: FAIL");
        return 1;
      }
    }

    int runFeatureTest(const ParsedArgs& args) {
      const std::filesystem::path skill = skillPath();
      if (skill.empty()) {
        std::println(stderr, "error: verify-noctalia skill not found");
        return 1;
      }

      const std::string_view featureName = args.positional(0);
      if (featureName.empty()) {
        std::println(stderr, "error: feature name required");
        std::println(stderr, "Run 'noctalia verify list' to see available features");
        return 1;
      }

      std::println("Feature verification not yet implemented: {}", featureName);
      std::println("Skill location: {}", skill.string());
      std::println("To run manually:");
      std::println("  cd {}", skill.string());
      std::println("  ./control-noctalia <command>");
      
      return 0;
    }

    int listFeatures() {
      std::println("Available verification features:");
      std::println("");
      std::println("  theme-mode-toggle   Dark/light theme transitions and portal sync");
      std::println("  panel-toggle        Panel open/close/toggle commands");
      std::println("  launcher-workflow   Launcher panel functionality");
      std::println("  notification-flow   Notification daemon and DND");
      std::println("  bar-widgets         Bar widget rendering and updates");
      std::println("  all                 Run all features sequentially");
      std::println("");
      std::println("Run: noctalia verify feature <feature-name>");
      
      return 0;
    }

  } // namespace

  int runVerifyCli(int argc, char* argv[]) {
    const auto parsed = parseArgs(kVerifyCmd, std::span<char* const>{argv + 2, static_cast<std::size_t>(argc - 2)});
    if (!parsed) {
      std::println(stderr, "{}", parsed.error());
      return 1;
    }

    if (parsed->helpRequested) {
      std::print("{}", renderHelp(kVerifyCmd, "noctalia verify"));
      return 0;
    }

    if (parsed->path.empty()) {
      std::print("{}", renderHelp(kVerifyCmd, "noctalia verify"));
      return 1;
    }

    const std::string_view subcommand = parsed->path.front()->name;

    if (subcommand == "doctor") {
      return runDoctor(*parsed);
    }

    if (subcommand == "feature") {
      return runFeatureTest(*parsed);
    }

    if (subcommand == "list") {
      return listFeatures();
    }

    std::println(stderr, "error: unknown verify subcommand: {}", subcommand);
    return 1;
  }

} // namespace noctalia::cli
