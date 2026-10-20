#include "compositors/mango/mango_runtime.h"

#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <poll.h>
#include <print>
#include <string>
#include <sys/socket.h>
#include <sys/un.h>
#include <thread>
#include <unistd.h>

int main() {
  char tempDir[] = "/tmp/noctalia-mango-test-XXXXXX";
  if (::mkdtemp(tempDir) == nullptr) {
    std::println(stderr, "mango_runtime_test: failed to create temporary directory");
    return 1;
  }

  const std::string socketPath = std::string(tempDir) + "/ipc.sock";
  const int listener = ::socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0);
  sockaddr_un addr{};
  addr.sun_family = AF_UNIX;
  std::memcpy(addr.sun_path, socketPath.c_str(), socketPath.size() + 1);
  if (listener < 0 || ::bind(listener, reinterpret_cast<const sockaddr*>(&addr), sizeof(addr)) < 0
      || ::listen(listener, 2) < 0 || ::setenv("MANGO_INSTANCE_SIGNATURE", socketPath.c_str(), 1) < 0) {
    std::println(stderr, "mango_runtime_test: failed to create local socket");
    if (listener >= 0) {
      ::close(listener);
    }
    ::unlink(socketPath.c_str());
    ::rmdir(tempDir);
    return 1;
  }

  bool serverOk = true;
  std::string receivedCommands[2];
  bool firstOk = false;
  bool secondAbsent = false;
  std::chrono::milliseconds blockedTime{};
  {
    std::jthread server([&] {
      for (int index = 0; index < 2; ++index) {
        pollfd incoming{.fd = listener, .events = POLLIN, .revents = 0};
        if (::poll(&incoming, 1, 3000) <= 0) {
          serverOk = false;
          return;
        }
        const int client = ::accept(listener, nullptr, nullptr);
        if (client < 0) {
          serverOk = false;
          return;
        }
        char buffer[128];
        while (!receivedCommands[index].contains('\n')) {
          const ssize_t count = ::recv(client, buffer, sizeof(buffer), 0);
          if (count <= 0) {
            serverOk = false;
            break;
          }
          receivedCommands[index].append(buffer, static_cast<std::size_t>(count));
        }
        if (index == 0) {
          const std::string reply = "{\"success\":true}\n";
          if (::send(client, reply.data(), reply.size(), MSG_NOSIGNAL)
              != static_cast<ssize_t>(reply.size())) {
            serverOk = false;
          }
        } else {
          // A peer that accepts commands but never replies must not stall the main loop.
          std::this_thread::sleep_for(std::chrono::milliseconds(1750));
        }
        ::close(client);
      }
    });

    compositors::mango::MangoRuntime runtime;
    const auto first = runtime.request("get all-clients");
    firstOk = first.has_value() && first->is_object() && first->value("success", false);
    const auto started = std::chrono::steady_clock::now();
    secondAbsent = !runtime.request("get all-clients").has_value();
    blockedTime = std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now() - started);
  }

  ::close(listener);
  ::unlink(socketPath.c_str());
  ::rmdir(tempDir);

  const bool commandsOk = receivedCommands[0] == "get all-clients\n"
      && receivedCommands[1] == "get all-clients\n";
  const bool bounded = blockedTime < std::chrono::milliseconds(1400);
  if (!serverOk || !commandsOk || !firstOk || !secondAbsent || !bounded) {
    std::println(
        stderr, "mango_runtime_test: server={} commands={} success={} timeout={} elapsed={}ms",
        serverOk, commandsOk, firstOk, secondAbsent, blockedTime.count()
    );
    return 1;
  }
  return 0;
}
