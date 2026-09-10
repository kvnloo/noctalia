#!/usr/bin/env bash
# Drive — Execute feature test scenarios

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

usage() {
    cat <<EOF
Usage: $0 <feature> [OPTIONS]

Execute Noctalia feature test scenarios via IPC.

FEATURES:
  bar                  Bar visibility and widgets
  control-center       Control center panels
  notifications        Notification toasts and history
  wallpaper            Wallpaper management
  launcher             Launcher search and providers

OPTIONS:
  --action=ACTION      Specific action (e.g., toggle, show, hide)
  --id=ID              Target ID (e.g., bar name)
  --help               Show this help

EXAMPLES:
  $0 bar --action=toggle --id=main
  $0 notifications --test-notify
  $0 launcher --action=open

EOF
}

ipc_send() {
    local cmd="$1"
    local binary="$REPO_ROOT/build-debug/noctalia"
    
    if [[ ! -x "$binary" ]]; then
        echo "[ERROR] Noctalia binary not found"
        return 1
    fi
    
    echo "[IPC] $cmd"
    "$binary" msg $cmd
}

drive_bar() {
    local action="toggle"
    local id="main"
    
    for arg in "$@"; do
        case "$arg" in
            --action=*) action="${arg#*=}" ;;
            --id=*) id="${arg#*=}" ;;
        esac
    done
    
    case "$action" in
        toggle) ipc_send "bar-toggle $id" ;;
        show) ipc_send "bar-show $id" ;;
        hide) ipc_send "bar-hide $id" ;;
        *) echo "[ERROR] Unknown action: $action"; return 1 ;;
    esac
}

drive_notifications() {
    local action="test-notify"
    
    for arg in "$@"; do
        case "$arg" in
            --test-notify) action="test-notify" ;;
        esac
    done
    
    case "$action" in
        test-notify)
            ipc_send 'notification-show "Verification Test" "This is a test notification from verify-noctalia skill"'
            ;;
        *) echo "[ERROR] Unknown action: $action"; return 1 ;;
    esac
}

drive_wallpaper() {
    local action="list"
    
    for arg in "$@"; do
        case "$arg" in
            --list) action="list" ;;
        esac
    done
    
    case "$action" in
        list)
            echo "[INFO] Opening wallpaper picker..."
            ipc_send "panel-open wallpaper"
            ;;
        *) echo "[ERROR] Unknown action: $action"; return 1 ;;
    esac
}

drive_launcher() {
    local action="open"
    
    for arg in "$@"; do
        case "$arg" in
            --action=*) action="${arg#*=}" ;;
        esac
    done
    
    case "$action" in
        open) ipc_send "panel-open launcher" ;;
        close) ipc_send "panel-close launcher" ;;
        toggle) ipc_send "panel-toggle launcher" ;;
        *) echo "[ERROR] Unknown action: $action"; return 1 ;;
    esac
}

drive_control_center() {
    local action="open"
    
    for arg in "$@"; do
        case "$arg" in
            --action=*) action="${arg#*=}" ;;
        esac
    done
    
    case "$action" in
        open) ipc_send "panel-open control-center" ;;
        close) ipc_send "panel-close control-center" ;;
        toggle) ipc_send "panel-toggle control-center" ;;
        *) echo "[ERROR] Unknown action: $action"; return 1 ;;
    esac
}

main() {
    if [[ $# -eq 0 ]]; then
        usage
        exit 1
    fi
    
    local feature="$1"
    shift
    
    case "$feature" in
        bar) drive_bar "$@" ;;
        notifications) drive_notifications "$@" ;;
        wallpaper) drive_wallpaper "$@" ;;
        launcher) drive_launcher "$@" ;;
        control-center) drive_control_center "$@" ;;
        --help|-h) usage; exit 0 ;;
        *) echo "[ERROR] Unknown feature: $feature"; usage; exit 1 ;;
    esac
}

main "$@"
