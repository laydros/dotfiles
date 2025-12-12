#!/bin/bash

# Brewfile Cross-Platform Sync
#
# Usage:
#   ./bundle-sync-brewfile.sh [--help]
#
# Shows what changes would be made, asks for confirmation, then executes.
# Combines Brewfile-core with OS-specific Brewfile (Brewfile-mac or Brewfile-linux).

set -euo pipefail

BREWFILE_DIR=~/.config/brew
BREWFILE_TEMP="$(mktemp)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()     { echo -e "${BLUE}[INFO]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1" >&2; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }

cleanup() {
    [[ -f "$BREWFILE_TEMP" ]] && rm -f "$BREWFILE_TEMP"
}
trap cleanup EXIT

show_help() {
    head -n 12 "$0" | grep '^#' | sed 's/^# *//'
}

# Handle --help
[[ "${1:-}" == "--help" ]] && { show_help; exit 0; }

# Validate prerequisites
command -v brew &>/dev/null || { error "Homebrew not found."; exit 1; }
[[ -d "$BREWFILE_DIR" ]] || { error "Brewfile directory not found: $BREWFILE_DIR"; exit 1; }
[[ -f "$BREWFILE_DIR/Brewfile-core" ]] || { error "Brewfile-core not found"; exit 1; }

# Detect OS and set OS-specific Brewfile
OS=$(uname)
case "$OS" in
    Darwin) OS_BREWFILE="$BREWFILE_DIR/Brewfile-mac"; log "Detected macOS" ;;
    Linux)  OS_BREWFILE="$BREWFILE_DIR/Brewfile-linux"; log "Detected Linux" ;;
    *)      error "Unsupported OS: $OS"; exit 1 ;;
esac

# Build combined Brewfile
cp "$BREWFILE_DIR/Brewfile-core" "$BREWFILE_TEMP"
if [[ -f "$OS_BREWFILE" ]]; then
    cat "$OS_BREWFILE" >> "$BREWFILE_TEMP"
    log "Combined Brewfile-core + $(basename "$OS_BREWFILE")"
else
    warn "OS-specific Brewfile not found: $OS_BREWFILE (using core only)"
fi

# Filter out macOS-only entries on Linux
if [[ "$OS" == "Linux" ]]; then
    sed -i '/^cask /d; /^mas /d' "$BREWFILE_TEMP"
fi

# Show what would change
echo ""
echo "=== PACKAGES TO INSTALL ==="
if brew bundle check --verbose --file="$BREWFILE_TEMP" 2>&1; then
    echo "  (all packages already installed)"
fi

echo ""
echo "=== PACKAGES TO REMOVE ==="
if brew bundle cleanup --file="$BREWFILE_TEMP" 2>&1; then
    echo "  (nothing to remove)"
fi

# Confirm before proceeding
echo ""
warn "This will install missing packages and remove unlisted packages."
read -p "Continue? [y/N] " -n 1 -r
echo
[[ $REPLY =~ ^[Yy]$ ]] || { log "Cancelled."; exit 0; }

# Execute
log "Syncing packages..."
if brew bundle install --cleanup --no-upgrade --file="$BREWFILE_TEMP"; then
    success "Brewfile sync completed."
else
    error "Sync failed."
    exit 1
fi
