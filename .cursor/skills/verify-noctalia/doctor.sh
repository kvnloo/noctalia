#!/usr/bin/env bash
# Doctor — Pre-flight verification for Noctalia environment

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

DRY_RUN=false
VERBOSE=false
EXIT_CODE=0

# ANSI colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $*"
}

check_repository() {
    log_info "Checking repository..."
    if [[ ! -d "$REPO_ROOT/.git" ]]; then
        log_error "Not in a git repository"
        return 1
    fi
    
    if [[ ! -f "$REPO_ROOT/meson.build" ]]; then
        log_error "meson.build not found (not Noctalia root?)"
        return 1
    fi
    
    log_success "Repository: $REPO_ROOT"
    return 0
}

check_build() {
    log_info "Checking build..."
    
    local build_dir="$REPO_ROOT/build-debug"
    local binary="$build_dir/noctalia"
    
    if [[ -x "$binary" ]]; then
        log_success "Build exists: $binary"
        
        # Check version
        if $VERBOSE; then
            local version
            version=$("$binary" --version 2>&1 || echo "version check failed")
            log_info "Version: $version"
        fi
        return 0
    fi
    
    log_warn "Build not found at $binary"
    log_info "Attempting to build..."
    
    if ! command -v just &>/dev/null; then
        log_error "just command not found (needed to build)"
        return 1
    fi
    
    cd "$REPO_ROOT"
    if just configure && just build; then
        log_success "Build completed successfully"
        return 0
    else
        log_error "Build failed"
        return 1
    fi
}

check_dependencies() {
    log_info "Checking runtime dependencies..."
    
    local missing=()
    
    # Core Wayland deps
    if ! pkg-config --exists wayland-client; then
        missing+=("wayland-client")
    fi
    
    if ! pkg-config --exists wayland-egl; then
        missing+=("wayland-egl")
    fi
    
    # Optional but important
    if ! command -v grim &>/dev/null; then
        log_warn "grim not found (screenshots will be limited)"
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing dependencies: ${missing[*]}"
        return 1
    fi
    
    log_success "Core dependencies present"
    return 0
}

check_compositor() {
    log_info "Checking Wayland compositor..."
    
    if [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
        log_error "WAYLAND_DISPLAY not set"
        return 2
    fi
    
    log_success "WAYLAND_DISPLAY=$WAYLAND_DISPLAY"
    
    # Try to detect compositor
    local compositor=""
    if pgrep -x hyprland &>/dev/null; then
        compositor="Hyprland"
    elif pgrep -x sway &>/dev/null; then
        compositor="Sway"
    elif pgrep -x niri &>/dev/null; then
        compositor="Niri"
    elif pgrep -x wayfire &>/dev/null; then
        compositor="Wayfire"
    elif pgrep -x labwc &>/dev/null; then
        compositor="Labwc"
    else
        log_warn "Compositor process not detected (may still work)"
        return 2
    fi
    
    log_success "Compositor: $compositor detected"
    return 0
}

check_config() {
    log_info "Checking configuration..."
    
    local example_config="$REPO_ROOT/example.toml"
    if [[ ! -f "$example_config" ]]; then
        log_error "example.toml not found"
        return 1
    fi
    
    log_success "example.toml exists"
    
    # Try to validate if binary available
    local binary="$REPO_ROOT/build-debug/noctalia"
    if [[ -x "$binary" ]]; then
        if "$binary" config validate "$example_config" &>/dev/null; then
            log_success "Config validates successfully"
        else
            log_error "Config validation failed"
            return 1
        fi
    fi
    
    return 0
}

check_ipc() {
    log_info "Checking IPC schema..."
    
    local binary="$REPO_ROOT/build-debug/noctalia"
    if [[ ! -x "$binary" ]]; then
        log_warn "Binary not available, skipping IPC check"
        return 2
    fi
    
    if "$binary" msg --help &>/dev/null; then
        log_success "IPC schema available"
        
        if $VERBOSE; then
            log_info "Sample IPC commands:"
            "$binary" msg --help | head -15
        fi
    else
        log_error "IPC help failed"
        return 1
    fi
    
    return 0
}

check_assets() {
    log_info "Checking runtime assets..."
    
    local assets_dir="$REPO_ROOT/assets"
    if [[ ! -d "$assets_dir" ]]; then
        log_error "assets/ directory not found"
        return 1
    fi
    
    # Check key assets
    local required=(
        "emoji.json"
        "fonts/noctalia-tabler.ttf"
        "templates/builtin.toml"
        "translations/en.json"
    )
    
    local missing=()
    for asset in "${required[@]}"; do
        if [[ ! -f "$assets_dir/$asset" ]]; then
            missing+=("$asset")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing assets: ${missing[*]}"
        return 1
    fi
    
    log_success "Required assets present"
    return 0
}

main() {
    echo "Noctalia Doctor — Pre-flight Verification"
    echo "=========================================="
    echo
    
    # Parse args
    for arg in "$@"; do
        case "$arg" in
            --dry-run)
                DRY_RUN=true
                log_info "Dry-run mode: skipping compositor checks"
                ;;
            --verbose)
                VERBOSE=true
                ;;
            --help|-h)
                cat <<EOF
Usage: $0 [OPTIONS]

Pre-flight checks for Noctalia verification environment.

OPTIONS:
  --dry-run     Skip compositor/runtime checks (for VMs without Wayland)
  --verbose     Show detailed output
  --help        Show this help

EXIT CODES:
  0   All checks passed
  1   Critical failure (build, config, deps)
  2   Warnings (compositor missing, optional deps)

EOF
                exit 0
                ;;
        esac
    done
    
    # Run checks
    check_repository || EXIT_CODE=1
    check_build || EXIT_CODE=1
    check_dependencies || EXIT_CODE=1
    
    if [[ "$DRY_RUN" == false ]]; then
        check_compositor || EXIT_CODE=2
    else
        log_info "Skipping compositor check (dry-run mode)"
    fi
    
    check_config || EXIT_CODE=1
    check_ipc || EXIT_CODE=2
    check_assets || EXIT_CODE=1
    
    echo
    if [[ $EXIT_CODE -eq 0 ]]; then
        log_success "All checks passed! Ready to verify Noctalia."
    elif [[ $EXIT_CODE -eq 2 ]]; then
        log_warn "Checks passed with warnings. Some features may be limited."
    else
        log_error "Critical checks failed. Fix errors before proceeding."
    fi
    
    exit $EXIT_CODE
}

main "$@"
