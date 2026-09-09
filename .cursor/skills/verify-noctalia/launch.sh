#!/usr/bin/env bash
# Launch — Start Noctalia instance for testing

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

DAEMON_MODE=false
LOG_FILE="/tmp/noctalia-verify.log"
CONFIG_FILE=""
TIMEOUT=10

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Launch Noctalia for verification testing.

OPTIONS:
  --daemon          Run in background (daemonize)
  --log=PATH        Log file path (default: /tmp/noctalia-verify.log)
  --config=PATH     Custom config file
  --timeout=SECS    IPC socket wait timeout (default: 10)
  --help            Show this help

ENVIRONMENT:
  Sets NOCTALIA_VERIFY_PID and NOCTALIA_VERIFY_SOCKET on success.

EOF
}

main() {
    for arg in "$@"; do
        case "$arg" in
            --daemon) DAEMON_MODE=true ;;
            --log=*) LOG_FILE="${arg#*=}" ;;
            --config=*) CONFIG_FILE="${arg#*=}" ;;
            --timeout=*) TIMEOUT="${arg#*=}" ;;
            --help|-h) usage; exit 0 ;;
            *) echo "Unknown option: $arg"; usage; exit 1 ;;
        esac
    done
    
    local binary="$REPO_ROOT/build-debug/noctalia"
    if [[ ! -x "$binary" ]]; then
        echo "[ERROR] Noctalia binary not found: $binary"
        echo "Run: just build"
        exit 1
    fi
    
    # Check if already running
    local socket="${XDG_RUNTIME_DIR:-/tmp}/noctalia-ipc.sock"
    if [[ -S "$socket" ]]; then
        echo "[WARN] Noctalia may already be running (socket exists: $socket)"
        echo "Stop existing instance first or use existing instance"
        exit 1
    fi
    
    echo "[INFO] Launching Noctalia..."
    echo "[INFO] Binary: $binary"
    echo "[INFO] Log: $LOG_FILE"
    
    local args=()
    if [[ "$DAEMON_MODE" == true ]]; then
        args+=(--daemon)
    fi
    
    # Set config if provided
    if [[ -n "$CONFIG_FILE" ]]; then
        export NOCTALIA_CONFIG_PATH="$CONFIG_FILE"
        echo "[INFO] Config: $CONFIG_FILE"
    fi
    
    # Launch
    if [[ "$DAEMON_MODE" == true ]]; then
        "$binary" "${args[@]}" > "$LOG_FILE" 2>&1 &
        local pid=$!
        echo "[INFO] Noctalia started in background (PID: $pid)"
    else
        "$binary" "${args[@]}" 2>&1 | tee "$LOG_FILE" &
        local pid=$!
        echo "[INFO] Noctalia started (PID: $pid)"
    fi
    
    # Wait for IPC socket
    echo "[INFO] Waiting for IPC socket (timeout: ${TIMEOUT}s)..."
    local elapsed=0
    while [[ ! -S "$socket" ]] && [[ $elapsed -lt $TIMEOUT ]]; do
        sleep 0.5
        elapsed=$((elapsed + 1))
        if ! kill -0 "$pid" 2>/dev/null; then
            echo "[ERROR] Noctalia process died during startup"
            echo "Check logs: $LOG_FILE"
            exit 1
        fi
    done
    
    if [[ ! -S "$socket" ]]; then
        echo "[ERROR] IPC socket not ready after ${TIMEOUT}s"
        echo "Check logs: $LOG_FILE"
        exit 1
    fi
    
    echo "[SUCCESS] Noctalia running and IPC ready"
    echo "PID: $pid"
    echo "Socket: $socket"
    echo "Log: $LOG_FILE"
    
    # Export for other scripts
    export NOCTALIA_VERIFY_PID="$pid"
    export NOCTALIA_VERIFY_SOCKET="$socket"
    
    echo
    echo "Environment variables set:"
    echo "  NOCTALIA_VERIFY_PID=$pid"
    echo "  NOCTALIA_VERIFY_SOCKET=$socket"
}

main "$@"
