#!/usr/bin/env bash
# Cleanup — Stop Noctalia and clean up test artifacts

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

KEEP_LOGS=false
KEEP_EVIDENCE=true

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Stop Noctalia instance and clean up test artifacts.

OPTIONS:
  --keep-logs       Don't delete log files
  --keep-evidence   Keep evidence artifacts (default: true)
  --help            Show this help

EOF
}

main() {
    for arg in "$@"; do
        case "$arg" in
            --keep-logs) KEEP_LOGS=true ;;
            --keep-evidence) KEEP_EVIDENCE=true ;;
            --help|-h) usage; exit 0 ;;
        esac
    done
    
    echo "[INFO] Cleaning up Noctalia test environment..."
    
    # Try IPC quit first
    local binary="$REPO_ROOT/build-debug/noctalia"
    if [[ -x "$binary" ]]; then
        local socket="${XDG_RUNTIME_DIR:-/tmp}/noctalia-ipc.sock"
        if [[ -S "$socket" ]]; then
            echo "[INFO] Sending quit via IPC..."
            "$binary" msg quit 2>/dev/null || echo "[WARN] IPC quit failed"
            sleep 1
        fi
    fi
    
    # Kill by PID if set
    if [[ -n "${NOCTALIA_VERIFY_PID:-}" ]]; then
        if kill -0 "$NOCTALIA_VERIFY_PID" 2>/dev/null; then
            echo "[INFO] Stopping Noctalia (PID: $NOCTALIA_VERIFY_PID)..."
            kill "$NOCTALIA_VERIFY_PID"
            sleep 1
            
            if kill -0 "$NOCTALIA_VERIFY_PID" 2>/dev/null; then
                echo "[WARN] Process still running, sending SIGKILL..."
                kill -9 "$NOCTALIA_VERIFY_PID"
            fi
        fi
    fi
    
    # Kill any stray noctalia processes
    pkill -f "noctalia" 2>/dev/null || true
    
    # Clean up socket
    local socket="${XDG_RUNTIME_DIR:-/tmp}/noctalia-ipc.sock"
    if [[ -S "$socket" ]]; then
        echo "[INFO] Removing IPC socket: $socket"
        rm -f "$socket"
    fi
    
    # Clean up logs
    if [[ "$KEEP_LOGS" == false ]]; then
        echo "[INFO] Removing logs..."
        rm -f /tmp/noctalia-verify.log
    else
        echo "[INFO] Keeping logs (--keep-logs)"
    fi
    
    # Evidence preserved by default
    if [[ "$KEEP_EVIDENCE" == true ]]; then
        echo "[INFO] Evidence artifacts preserved in /tmp/noctalia-evidence/"
    fi
    
    echo "[SUCCESS] Cleanup complete"
}

main "$@"
