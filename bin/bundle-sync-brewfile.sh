#!/bin/bash

# Brewfile Cross-Platform Installer (Improved)
#
# Usage:
#   ./bundle-sync-brewfile.sh [--preview] [--verbose] [--help]
#
# Options:
#   --preview     Show what changes would be made without executing
#   --verbose     Show all packages including already installed ones
#   --help        Show this help message
#
# Safety features:
# - Preview mode shows all changes before execution
# - Validates Brewfile existence before proceeding
# - Better error handling and logging
# - Confirms destructive operations

set -euo pipefail  # Exit on error, undefined vars, pipe failures

BREWFILE_DIR=~/.config/brew
BREWFILE_TEMP="/tmp/Brewfile.$$"  # Use PID for unique temp file
PREVIEW_MODE=false
VERBOSE=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

cleanup() {
    if [[ -f "$BREWFILE_TEMP" ]]; then
        rm "$BREWFILE_TEMP"
        log "Cleaned up temporary Brewfile"
    fi
}

trap cleanup EXIT

show_help() {
    head -n 20 "$0" | grep '^#' | sed 's/^# *//'
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --preview)
            PREVIEW_MODE=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validate prerequisites
if ! command -v brew &> /dev/null; then
    error "Homebrew not found. Please install Homebrew first."
    exit 1
fi

if [[ ! -d "$BREWFILE_DIR" ]]; then
    error "Brewfile directory not found: $BREWFILE_DIR"
    exit 1
fi

if [[ ! -f "$BREWFILE_DIR/Brewfile-core" ]]; then
    error "Core Brewfile not found: $BREWFILE_DIR/Brewfile-core"
    exit 1
fi

# Determine OS and check for OS-specific Brewfile
OS=$(uname)
if [[ "$OS" == "Darwin" ]]; then
    OS_BREWFILE="$BREWFILE_DIR/Brewfile-mac"
    log "Detected macOS"
elif [[ "$OS" == "Linux" ]]; then
    OS_BREWFILE="$BREWFILE_DIR/Brewfile-linux"
    log "Detected Linux"
else
    error "Unsupported operating system: $OS"
    exit 1
fi

# Check if OS-specific Brewfile exists (optional)
HAS_OS_BREWFILE=false
if [[ -f "$OS_BREWFILE" ]]; then
    HAS_OS_BREWFILE=true
    log "Found OS-specific Brewfile: $OS_BREWFILE"
else
    warn "OS-specific Brewfile not found: $OS_BREWFILE (continuing with core only)"
fi

# Build combined Brewfile
log "Building combined Brewfile..."
cp "$BREWFILE_DIR/Brewfile-core" "$BREWFILE_TEMP"

if [[ "$HAS_OS_BREWFILE" == true ]]; then
    cat "$OS_BREWFILE" >> "$BREWFILE_TEMP"
fi

# Additional safety for Linux
if [[ "$OS" == "Linux" ]]; then
    log "Filtering macOS-only entries for Linux..."
    sed -i '/^cask /d' "$BREWFILE_TEMP"
    sed -i '/^mas /d' "$BREWFILE_TEMP"
fi

# Show what's in the combined Brewfile
log "Combined Brewfile contains:"
echo "  Core packages: $(grep -c '^brew ' "$BREWFILE_DIR/Brewfile-core" || echo 0)"
if [[ "$HAS_OS_BREWFILE" == true ]]; then
    echo "  OS-specific packages: $(grep -c '^brew ' "$OS_BREWFILE" || echo 0)"
    if [[ "$OS" == "Darwin" ]]; then
        echo "  Casks: $(grep -c '^cask ' "$OS_BREWFILE" || echo 0)"
        echo "  Mac App Store: $(grep -c '^mas ' "$OS_BREWFILE" || echo 0)"
    fi
else
    echo "  OS-specific packages: 0 (no OS-specific Brewfile)"
fi

# Preview mode - show what would change
if [[ "$PREVIEW_MODE" == true ]]; then
    log "PREVIEW MODE - No changes will be made"
    
    echo ""
    echo "=== PACKAGES THAT WOULD BE INSTALLED ==="
    NEW_PACKAGES=()
    EXISTING_PACKAGES=0
    while read -r formula; do
        if ! brew list --formula --quiet "$formula" &>/dev/null && 
           ! brew list --cask --quiet "$formula" &>/dev/null; then
            NEW_PACKAGES+=("$formula")
            echo "  + $formula"
        else
            ((EXISTING_PACKAGES++))
            if [[ "$VERBOSE" == true ]]; then
                echo "  ✓ $formula (already installed)"
            fi
        fi
    done < <(brew bundle list --file="$BREWFILE_TEMP")
    
    if [[ ${#NEW_PACKAGES[@]} -eq 0 ]]; then
        echo "  (no new packages to install)"
    fi
    
    echo ""
    echo "Summary: ${#NEW_PACKAGES[@]} new, $EXISTING_PACKAGES already installed"
    if [[ "$VERBOSE" != true && $EXISTING_PACKAGES -gt 0 ]]; then
        echo "(use --verbose to see already installed packages)"
    fi
    
    echo ""
    echo "=== PACKAGES THAT WOULD BE REMOVED ==="
    # This is a bit complex to preview accurately without actually running cleanup
    # We can show currently installed packages not in the Brewfile
    comm -23 \
        <(brew list --formula | sort) \
        <(grep '^brew ' "$BREWFILE_TEMP" | cut -d'"' -f2 | sort) | \
        sed 's/^/  - /'
    
    if [[ "$OS" == "Darwin" ]]; then
        echo ""
        echo "=== CASKS THAT WOULD BE REMOVED ==="
        comm -23 \
            <(brew list --cask | sort) \
            <(grep '^cask ' "$BREWFILE_TEMP" | cut -d'"' -f2 | sort) | \
            sed 's/^/  - /'
    fi
    
    echo ""
    echo "To execute these changes, run without --preview"
    exit 0
fi

# Confirm destructive operations
echo ""
warn "This will install packages and REMOVE packages not in your Brewfiles."
read -p "Continue? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log "Cancelled by user"
    exit 0
fi

# Execute the installation and cleanup
log "Installing packages..."
if brew bundle install --no-upgrade --file="$BREWFILE_TEMP"; then
    success "Packages installed successfully"
else
    error "Package installation failed"
    exit 1
fi

log "Cleaning up unused packages..."
if brew bundle cleanup --file="$BREWFILE_TEMP" --force; then
    success "Cleanup completed successfully"
else
    warn "Cleanup had issues, but continuing..."
fi

success "Brewfile sync completed successfully"
