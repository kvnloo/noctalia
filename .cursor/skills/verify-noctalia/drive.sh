#!/usr/bin/env bash
# Drive — thin IPC harness for feature smoke (align to staging docs/user/ipc)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

usage() {
    cat <<EOF
Usage: $0 <feature> [OPTIONS]

FEATURES:
  bar                  bar-show|hide|toggle
  control-center       panel-open|close|toggle control-center
  notifications        notification-show smoke
  wallpaper            wallpaper-get|next|previous|random | panel-toggle wallpaper
  launcher             panel-open|close|toggle launcher
  theme-mode-toggle    theme-mode-toggle (+ resolved get)

OPTIONS:
  --action=ACTION      Feature-specific action
  --id=ID              Optional bar name / monitor selector
  --help               Show this help
EOF
}

ipc_send() {
    local cmd="$1"
    local binary="$REPO_ROOT/build-debug/noctalia"
    if [[ ! -x "$binary" ]]; then
        if command -v noctalia >/dev/null 2>&1; then
            binary="$(command -v noctalia)"
        else
            echo "[ERROR] Noctalia binary not found"
            return 1
        fi
    fi
    echo "[IPC] $cmd"
    # shellcheck disable=SC2086
    "$binary" msg $cmd
}

drive_bar() {
    local action="toggle"
    local id=""
    for arg in "$@"; do
        case "$arg" in
            --action=*) action="${arg#*=}" ;;
            --id=*) id="${arg#*=}" ;;
        esac
    done
    case "$action" in
        toggle) ipc_send "bar-toggle ${id}" ;;
        show) ipc_send "bar-show ${id}" ;;
        hide) ipc_send "bar-hide ${id}" ;;
        *) echo "[ERROR] Unknown action: $action"; return 1 ;;
    esac
}

drive_notifications() {
    ipc_send 'notification-show "Verification Test" "This is a test notification from verify-noctalia skill"'
}

drive_wallpaper() {
    local action="list"
    local id=""
    for arg in "$@"; do
        case "$arg" in
            --list) action="list" ;;
            --action=*) action="${arg#*=}" ;;
            --id=*) id="${arg#*=}" ;;
        esac
    done
    case "$action" in
        list|picker) ipc_send "panel-toggle wallpaper" ;;
        get) ipc_send "wallpaper-get ${id}" ;;
        next) ipc_send "wallpaper-next ${id}" ;;
        previous|prev) ipc_send "wallpaper-previous ${id}" ;;
        random) ipc_send "wallpaper-random ${id}" ;;
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
    local action="toggle"
    local tab=""
    for arg in "$@"; do
        case "$arg" in
            --action=*) action="${arg#*=}" ;;
            --tab=*) tab="${arg#*=}" ;;
        esac
    done
    case "$action" in
        open) ipc_send "panel-open control-center ${tab}" ;;
        close) ipc_send "panel-close control-center" ;;
        toggle) ipc_send "panel-toggle control-center ${tab}" ;;
        *) echo "[ERROR] Unknown action: $action"; return 1 ;;
    esac
}

drive_theme_mode_toggle() {
    ipc_send "theme-mode-get"
    ipc_send "theme-mode-toggle"
    ipc_send "theme-mode-get"
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
        theme-mode-toggle) drive_theme_mode_toggle "$@" ;;
        --help|-h) usage; exit 0 ;;
        *) echo "[ERROR] Unknown feature: $feature"; usage; exit 1 ;;
    esac
}

main "$@"
