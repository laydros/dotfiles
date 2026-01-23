---
name: z3-dev-server
description: Manage the z3 development server for the WBS Access application. This skill should be used when needing to start, stop, or restart the z3 Rust/Axum server during development. Handles finding existing server processes, killing them, and launching fresh instances. Templates are compiled in, so code changes require server restart.
---

# z3 Dev Server

## Overview

This skill manages the z3 development server lifecycle. Since Askama templates are compiled into the Rust binary, any changes to templates or Rust code require recompilation and server restart. Only changes to `static/` files are served directly without restart.

The restart script **auto-detects template changes** and forces a clean rebuild when needed. This ensures template modifications are always compiled in, avoiding stale template issues from Cargo's incremental compilation.

## Quick Reference

| Action | Command |
|--------|---------|
| Restart server | Run `scripts/restart.sh` |
| Check if running | `lsof -i :$PORT -P -n` |
| View logs | Check output file from background task |

## Workflow

### Restarting the Server

To restart the z3 dev server after making changes:

1. Run the restart script from the skill directory:
   ```bash
   /Users/laydros/.claude/skills/z3-dev-server/scripts/restart.sh
   ```

The script will:
- Read PORT from `z3/.env` (defaults to 3000 if not set)
- Find and kill any existing process on that port
- **Auto-detect if any template files are newer than the binary**
- If templates changed: run `cargo clean -p z3` to force recompilation
- If no template changes: use fast incremental build
- Start `cargo run` in the z3 directory as a background process
- Wait for the server to be ready
- Report success or failure

### Manual Operations

If needed, individual operations can be performed:

**Find server process:**
```bash
lsof -i :3005 -P -n
```

**Kill server:**
```bash
kill $(lsof -t -i :3005)
```

**Force clean rebuild (if auto-detect isn't catching something):**
```bash
cd /Users/laydros/src/f500/wbsaccessapp/z3 && cargo clean -p z3 && cargo run
```

**Start server in background:**
```bash
cd /Users/laydros/src/f500/wbsaccessapp/z3 && cargo run &
```

## Configuration

The server reads configuration from `z3/.env`:

| Variable | Default | Description |
|----------|---------|-------------|
| PORT | 3000 | Server port |
| HOST | 127.0.0.1 | Bind address |
| DATABASE_URL | (required) | MSSQL connection string |

## When Restart is Required

**Restart needed:**
- Any `.rs` file changes
- Any template changes (`templates/*.html`) - auto-detected and clean rebuilt
- `Cargo.toml` changes
- `.env` changes

**No restart needed:**
- CSS/JS changes in `static/`
- Image/asset changes in `static/`

## Technical Notes

Askama templates are compiled via a procedural macro at build time. Cargo's incremental compilation doesn't always detect template file changes because the dependency tracking for proc macros is imperfect. The auto-detection in this script works around this by comparing template file modification times against the compiled binary and forcing a `cargo clean -p z3` when templates are newer.
