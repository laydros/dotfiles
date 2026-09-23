---
name: session-commit
description: Wrap up a work session by updating documentation, plans, and memory, then creating a clean commit. This skill should be used when finishing a block of work - whether infrastructure/IT or software development - and needing to ensure everything is documented and committed properly. Invoke with /session-commit.
---

# Session Commit

Wrap up a work session cleanly: update docs, record context, commit. Works for any project type - infrastructure, application code, configuration, documentation.

## Workflow

### 1. Assess what changed

- Run `git status` (never use `-uall`) and `git diff` to understand staged and unstaged changes
- Run `git log --oneline -5` to see recent commit context
- If a plan or TODO file exists in the repo root or `docs/plans/`, read it to understand what work was being tracked

### 2. Update documentation

Scan the repo for documentation files and update any that are affected by the session's changes. Common patterns by project type:

**Any project:**
- `TODO.md` or `docs/plans/*.md` - Mark completed items, update status
- `CHANGELOG.md` - Add entry for notable changes
- `README.md` - Update if features, setup steps, or usage changed

**Infrastructure/Ansible projects:**
- `inventory/` files - Update if hosts, groups, or variables changed
- Host documentation (e.g., `docs/hosts/*.md`, `docs/*.md`) - Update if host configuration changed
- Role or playbook documentation

**Software projects:**
- `CLAUDE.md` or `AGENTS.md` - Update if commands, architecture, or workflows changed
- API documentation - Update if endpoints or interfaces changed

Do not update files that are unaffected by the session's work. Only touch what actually changed.

### 3. Save what's worth keeping

Put each durable fact in its one home: repo docs for anything about the code, memory for decisions and preferences that aren't in the repo. Skip this if the session was routine. Don't copy a fact that already lives somewhere else; point to it.

### 4. Stage and commit

- Stage relevant files by name (avoid `git add -A` or `git add .`)
- Draft a concise commit message summarizing the work (1-2 sentences focused on the "why")
- Present the commit message for approval
- Create the commit
- Run `git status` to confirm clean state
- Do NOT push unless explicitly asked

### 5. Show summary

Display a brief summary:
- What was completed (referencing plan items if applicable)
- What documentation was updated
- What remains to be done (if a plan/TODO exists with incomplete items)

## Important constraints

- Respect all git rules from CLAUDE.md (no push without permission, no Claude references in commit messages, etc.)
- Do not create documentation files that don't already exist - only update existing ones
- If there are no changes to commit, say so and skip to step 3
- If uncommitted changes exist from before this session, flag them and ask how to handle them before proceeding
