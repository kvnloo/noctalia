#include "compositors/mango/mango_runtime.h"

#include <atomic>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <functional>
#include <poll.h>
#include <stdexcept>
#include <string>
#include <sys/socket.h>
#include <sys/un.h>
#include <thread>
#include <unistd.h>

namespace {

  class TestSocketServer {
  public:
    explicit TestSocketServer(std::function<void(int)> handleClient) {
      char path[] = "/tmp/noctalia-mango-request-XXXXXX";
      const int temporary = ::mkstemp(path);
      if (temporary < 0) {
        throw std::runtime_error("failed to allocate test socket path");
      }
      ::close(temporary);
      ::unlink(path);
      m_path = path;

      m_listener = ::socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0);
      if (m_listener < 0) {
        throw std::runtime_error("failed to create test listener");
      }
      sockaddr_un addr{};
      addr.sun_family = AF_UNIX;
      std::memcpy(addr.sun_path, m_path.c_str(), m_path.size() + 1);
      if (::bind(m_listener, reinterpret_cast<const sockaddr*>(&addr), sizeof(addr)) < 0
          || ::listen(m_listener, 1) < 0) {
        ::close(m_listener);
        ::unlink(m_path.c_str());
        throw std::runtime_error("failed to bind test listener");
      }
      m_worker = std::thread([this, handleClient = std::move(handleClient)] {
        pollfd listener{.fd = m_listener, .events = POLLIN, .revents = 0};
        if (::poll(&listener, 1, 1500) <= 0) {
          return;
        }
        const int client = ::accept(m_listener, nullptr, nullptr);
        if (client < 0) {
          return;
        }
        handleClient(client);
        ::close(client);
      });
    }

    ~TestSocketServer() {
      if (m_worker.joinable()) {
        m_worker.join();
      }
      if (m_listener >= 0) {
        ::close(m_listener);
      }
      ::unlink(m_path.c_str());
    }

    TestSocketServer(const TestSocketServer&) = delete;
    TestSocketServer& operator=(const TestSocketServer&) = delete;

    [[nodiscard]] const std::string& path() const { return m_path; }

  private:
    std::string m_path;
    int m_listener = -1;
    std::thread m_worker;
  };

  std::string readCommand(int fd) {
    char buffer[256]{};
    const ssize_t count = ::recv(fd, buffer, sizeof(buffer), 0);
    return count > 0 ? std::string(buffer, static_cast<std::size_t>(count)) : std::string{};
  }

} // namespace

int main() {
  using namespace std::chrono_literals;
  std::atomic<bool> receivedCorrectCommand = false;
  {
    TestSocketServer server([&receivedCorrectCommand](int fd) {
      receivedCorrectCommand.store(readCommand(fd) == "get tags\n");
      constexpr char response[] = "{\"success\":true}\n";
      (void)::send(fd, response, sizeof(response) - 1, MSG_NOSIGNAL);
    });
    (void)::setenv("MANGO_INSTANCE_SIGNATURE", server.path().c_str(), 1);
    const compositors::mango::MangoRuntime runtime;
    const auto reply = runtime.request("get tags");
    if (!reply.has_value() || reply->value("success", false) != true || !receivedCorrectCommand.load()) {
      std::fprintf(stderr, "mango_runtime_test: valid IPC request/response failed\n");
      return 1;
    }
  }

  {
    // The peer accepts the command but never replies before the global deadline.
    // On the old blocking read path this takes the full server delay (1800ms).
    TestSocketServer server([](int fd) {
      (void)readCommand(fd);
      std::this_thread::sleep_for(1800ms);
    });
    (void)::setenv("MANGO_INSTANCE_SIGNATURE", server.path().c_str(), 1);
    const compositors::mango::MangoRuntime runtime;
    const auto start = std::chrono::steady_clock::now();
    const auto reply = runtime.request("get all-clients");
    const auto elapsed = std::chrono::steady_clock::now() - start;
    if (reply.has_value() || elapsed > 1300ms) {
      std::fprintf(stderr, "mango_runtime_test: stalled IPC request exceeded deadline\n");
      return 1;
    }
  }

  (void)::unsetenv("MANGO_INSTANCE_SIGNATURE");
  return 0;
}
