#include "compositors/mango/mango_runtime.h"

#include <atomic>
#include <chrono>
#include <cerrno>
#include <cstdlib>
#include <cstring>
#include <iostream>
#include <optional>
#include <poll.h>
#include <string>
#include <sys/socket.h>
#include <sys/un.h>
#include <thread>
#include <unistd.h>
#include <vector>

namespace {

  bool check(bool condition, const char* message) {
    if (!condition) {
      std::cerr << "mango_runtime_test: FAIL: " << message << '\n';
    }
    return condition;
  }

} // namespace

int main() {
  bool ok = true;
  const std::string path = "/tmp/noctalia-mango-runtime-test-" + std::to_string(::getpid()) + ".sock";
  ::unlink(path.c_str());

  const int listener = ::socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0);
  if (!check(listener >= 0, "failed to create listener")) {
    return 1;
  }

  sockaddr_un address{};
  address.sun_family = AF_UNIX;
  if (!check(path.size() < sizeof(address.sun_path), "socket path too long")) {
    ::close(listener);
    return 1;
  }
  std::memcpy(address.sun_path, path.c_str(), path.size() + 1);
  if (!check(::bind(listener, reinterpret_cast<const sockaddr*>(&address), sizeof(address)) == 0, "bind failed")
      || !check(::listen(listener, 2) == 0, "listen failed")) {
    ::close(listener);
    ::unlink(path.c_str());
    return 1;
  }

  std::optional<std::string> savedEnv;
  if (const char* previousEnv = std::getenv("MANGO_INSTANCE_SIGNATURE"); previousEnv != nullptr) {
    savedEnv = previousEnv;
  }
  if (!check(::setenv("MANGO_INSTANCE_SIGNATURE", path.c_str(), 1) == 0, "failed to set socket environment")) {
    ::close(listener);
    ::unlink(path.c_str());
    return 1;
  }

  std::atomic<int> serverError{0};
  std::vector<std::string> requests;
  std::jthread server([&]() {
    for (int i = 0; i < 2; ++i) {
      pollfd pending{.fd = listener, .events = POLLIN, .revents = 0};
      if (::poll(&pending, 1, 3000) <= 0 || (pending.revents & POLLIN) == 0) {
        serverError = 1;
        return;
      }
      const int client = ::accept4(listener, nullptr, nullptr, SOCK_CLOEXEC);
      if (client < 0) {
        serverError = 2;
        return;
      }

      std::string request;
      char buffer[256];
      while (!request.contains('\n')) {
        pollfd ready{.fd = client, .events = POLLIN, .revents = 0};
        if (::poll(&ready, 1, 2000) <= 0 || (ready.revents & POLLIN) == 0) {
          serverError = 3;
          ::close(client);
          return;
        }
        const ssize_t count = ::recv(client, buffer, sizeof(buffer), 0);
        if (count <= 0) {
          serverError = 4;
          ::close(client);
          return;
        }
        request.append(buffer, static_cast<std::size_t>(count));
        if (request.size() > 4096) {
          serverError = 5;
          ::close(client);
          return;
        }
      }
      requests.push_back(request);

      if (i == 0) {
        constexpr std::string_view response = "{\"clients\":[]}\n";
        if (::send(client, response.data(), response.size(), MSG_NOSIGNAL)
            != static_cast<ssize_t>(response.size())) {
          serverError = 6;
          ::close(client);
          return;
        }
      } else {
        // Keep the peer connected longer than the deadline: the client must not block the UI thread.
        std::this_thread::sleep_for(std::chrono::milliseconds(2400));
      }
      ::close(client);
    }
  });

  compositors::mango::MangoRuntime runtime;
  runtime.refresh();
  const auto response = runtime.request("get all-clients");
  ok &= check(response.has_value(), "fast request should return a JSON response");
  ok &= check(response && response->is_object() && response->contains("clients"), "fast response should parse");

  const auto start = std::chrono::steady_clock::now();
  const auto timedOut = runtime.request("get all-clients");
  const auto elapsed = std::chrono::steady_clock::now() - start;
  ok &= check(!timedOut.has_value(), "unresponsive peer should time out");
  ok &= check(elapsed < std::chrono::milliseconds(1600), "request must return before an unresponsive peer closes");

  server.join();
  ok &= check(serverError == 0, "mock server should accept both requests");
  ok &= check(requests.size() == 2, "mock server should receive two requests");
  if (requests.size() == 2) {
    ok &= check(requests[0] == "get all-clients\n", "fast command must be newline-terminated");
    ok &= check(requests[1] == "get all-clients\n", "timed-out command must be newline-terminated");
  }

  if (savedEnv) {
    static_cast<void>(::setenv("MANGO_INSTANCE_SIGNATURE", savedEnv->c_str(), 1));
  } else {
    static_cast<void>(::unsetenv("MANGO_INSTANCE_SIGNATURE"));
  }
  ::close(listener);
  ::unlink(path.c_str());
  return ok ? 0 : 1;
}
