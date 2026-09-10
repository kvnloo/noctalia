#!/usr/bin/env bash
# Snapshot — Capture verification evidence

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

EVIDENCE_DIR="/tmp/noctalia-evidence"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

usage() {
    cat <<EOF
Usage: $0 <name> [OPTIONS]

Capture verification evidence artifacts.

OPTIONS:
  --type=TYPE      Artifact type: screenshot | log | state | all (default: all)
  --help           Show this help

EXAMPLES:
  $0 bar-toggle
  $0 test-notifications --type=screenshot
  $0 full-test --type=all

OUTPUT:
  Artifacts saved to: $EVIDENCE_DIR/<timestamp>-<name>/

EOF
}

capture_screenshot() {
    local output="$1"
    echo "[INFO] Capturing screenshot..."
    
    if command -v grim &>/dev/null; then
        grim "$output" 2>/dev/null && echo "[SUCCESS] Screenshot: $output" && return 0
    fi
    
    if command -v hyprctl &>/dev/null; then
        hyprctl screenshot "$output" 2>/dev/null && echo "[SUCCESS] Screenshot: $output" && return 0
    fi
    
    echo "[WARN] Screenshot tool not available (grim, hyprctl not found)"
    return 1
}

capture_log() {
    local output="$1"
    echo "[INFO] Capturing logs..."
    
    if [[ -f "/tmp/noctalia-verify.log" ]]; then
        cp "/tmp/noctalia-verify.log" "$output"
        echo "[SUCCESS] Log: $output"
        return 0
    fi
    
    echo "[WARN] No log file found at /tmp/noctalia-verify.log"
    return 1
}

capture_state() {
    local output_dir="$1"
    echo "[INFO] Capturing state..."
    
    local binary="/workspace/build-debug/noctalia"
    if [[ ! -x "$binary" ]]; then
        echo "[WARN] Noctalia binary not available for state capture"
        return 1
    fi
    
    # IPC handlers
    "$binary" msg --help > "$output_dir/ipc-handlers.txt" 2>&1 || true
    
    # Config validation
    if [[ -f "/workspace/example.toml" ]]; then
        cp "/workspace/example.toml" "$output_dir/config.toml"
    fi
    
    echo "[SUCCESS] State captured to $output_dir"
    return 0
}

main() {
    if [[ $# -eq 0 ]]; then
        usage
        exit 1
    fi
    
    local name="$1"
    shift
    
    local type="all"
    for arg in "$@"; do
        case "$arg" in
            --type=*) type="${arg#*=}" ;;
            --help|-h) usage; exit 0 ;;
        esac
    done
    
    local snapshot_dir="$EVIDENCE_DIR/$TIMESTAMP-$name"
    mkdir -p "$snapshot_dir"
    
    echo "[INFO] Snapshot: $snapshot_dir"
    
    case "$type" in
        screenshot)
            capture_screenshot "$snapshot_dir/screenshot.png"
            ;;
        log)
            capture_log "$snapshot_dir/noctalia.log"
            ;;
        state)
            capture_state "$snapshot_dir"
            ;;
        all)
            capture_screenshot "$snapshot_dir/screenshot.png" || true
            capture_log "$snapshot_dir/noctalia.log" || true
            capture_state "$snapshot_dir" || true
            ;;
        *)
            echo "[ERROR] Unknown type: $type"
            usage
            exit 1
            ;;
    esac
    
    echo
    echo "[SUCCESS] Snapshot complete: $snapshot_dir"
    ls -lh "$snapshot_dir"
}

main "$@"
