#!/bin/bash
# z3 Dev Server Restart Script
# Finds and kills existing server, then starts a fresh instance
# Auto-detects when templates have changed and forces recompilation

set -e

# Find the z3 directory - look for it relative to current worktree
find_z3_dir() {
    # Check common locations
    local candidates=(
        "./z3"
        "../z3"
        "."
    )

    for dir in "${candidates[@]}"; do
        if [[ -f "$dir/Cargo.toml" ]] && grep -q 'name = "z3"' "$dir/Cargo.toml" 2>/dev/null; then
            echo "$(cd "$dir" && pwd)"
            return 0
        fi
    done

    # Try to find via git root
    local git_root
    git_root=$(git rev-parse --show-toplevel 2>/dev/null) || true
    if [[ -n "$git_root" && -f "$git_root/z3/Cargo.toml" ]]; then
        echo "$git_root/z3"
        return 0
    fi

    return 1
}

# Get port from .env file
get_port() {
    local env_file="$1/.env"
    if [[ -f "$env_file" ]]; then
        grep -E '^PORT=' "$env_file" 2>/dev/null | cut -d'=' -f2 | tr -d ' \r\n' || echo "3000"
    else
        echo "3000"
    fi
}

# Get file modification time (portable across macOS and Linux)
get_mtime() {
    local file="$1"
    if [[ "$(uname)" == "Darwin" ]]; then
        stat -f %m "$file" 2>/dev/null
    else
        stat -c %Y "$file" 2>/dev/null
    fi
}

# Check if any template is newer than the binary
templates_need_rebuild() {
    local z3_dir="$1"
    local binary="$z3_dir/target/debug/z3"
    local templates_dir="$z3_dir/templates"

    # If binary doesn't exist, no need for clean (fresh build anyway)
    if [[ ! -f "$binary" ]]; then
        return 1
    fi

    # If templates directory doesn't exist, no templates to check
    if [[ ! -d "$templates_dir" ]]; then
        return 1
    fi

    # Check if any template file is newer than the binary
    local binary_mtime
    binary_mtime=$(get_mtime "$binary") || return 1

    while IFS= read -r -d '' template; do
        local template_mtime
        template_mtime=$(get_mtime "$template") || continue
        if [[ "$template_mtime" -gt "$binary_mtime" ]]; then
            echo "Template newer than binary: $template"
            return 0
        fi
    done < <(find "$templates_dir" -name "*.html" -print0 2>/dev/null)

    return 1
}

# Main
Z3_DIR=$(find_z3_dir) || {
    echo "ERROR: Could not find z3 directory"
    echo "Run this from the wbsaccessapp worktree or its z3 subdirectory"
    exit 1
}

PORT=$(get_port "$Z3_DIR")
PORT=${PORT:-3000}

echo "z3 directory: $Z3_DIR"
echo "Server port: $PORT"

# Kill existing process on port
EXISTING_PID=$(lsof -t -i :"$PORT" 2>/dev/null || true)
if [[ -n "$EXISTING_PID" ]]; then
    echo "Killing existing process on port $PORT (PID: $EXISTING_PID)"
    kill "$EXISTING_PID" 2>/dev/null || true
    sleep 1
    # Force kill if still running
    if lsof -t -i :"$PORT" >/dev/null 2>&1; then
        echo "Force killing..."
        kill -9 "$EXISTING_PID" 2>/dev/null || true
        sleep 1
    fi
else
    echo "No existing process on port $PORT"
fi

# Check if templates need rebuild
cd "$Z3_DIR"
if templates_need_rebuild "$Z3_DIR"; then
    echo ""
    echo "Templates modified since last build - cleaning z3 artifacts..."
    cargo clean -p z3
    echo "Clean complete."
else
    echo "No template changes detected - using incremental build."
fi

# Start server
echo ""
echo "Starting z3 server..."

# Run cargo in background, redirect output to temp file
OUTPUT_FILE="/tmp/z3-server-$$.log"
nohup cargo run > "$OUTPUT_FILE" 2>&1 &
SERVER_PID=$!

echo "Server starting (PID: $SERVER_PID)"
echo "Output: $OUTPUT_FILE"

# Wait for server to be ready (check for listening port)
echo "Waiting for server to be ready..."
for i in {1..60}; do
    if lsof -i :"$PORT" -P -n 2>/dev/null | grep -q LISTEN; then
        echo "Server ready on port $PORT"
        # Show last few lines of output
        echo ""
        echo "Recent output:"
        tail -5 "$OUTPUT_FILE" 2>/dev/null || true
        exit 0
    fi

    # Check if process died
    if ! kill -0 "$SERVER_PID" 2>/dev/null; then
        echo "ERROR: Server process died"
        echo "Output:"
        cat "$OUTPUT_FILE"
        exit 1
    fi

    sleep 1
done

echo "WARNING: Server may not be ready yet (timeout waiting for port $PORT)"
echo "Check output: $OUTPUT_FILE"
exit 1
