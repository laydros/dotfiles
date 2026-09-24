---
name: context-cleanup
description: Clean up a repo's Claude instructions (CLAUDE.md, AGENTS.md, repo skills) for current Claude models, sweep its private journal into proper homes, and dedupe facts. Use when Jason asks for the "context cleanup pass" in a repo, or to slim a CLAUDE.md or AGENTS.md.
---

# Context cleanup

One repo per session, started in that repo. Nothing here commits or deletes without Jason's say-so.

Per-repo notes (who owns what, which repos are done or out of scope): vault `work/projects/claude-context-cleanup/claude-context-cleanup.md`. Read it first. Some repos belong to someone else (wydocs is Scott's, wychecks is Roger's) and must not be reshaped without them.

## 1. Check what actually loads

Any `CLAUDE.md` in the working directory or above blocks `AGENTS.md` by default, and `~/src/f500/CLAUDE.md` sits above every f500 repo. So a repo with only `AGENTS.md` loads none of it. The fix is a one-line `CLAUDE.md` containing `@AGENTS.md`; the import never loads it twice. Use the import, not a symlink: Windows git checks symlinks out as text files.

## 2. Run the audit

Run `/claude-api prompt-audit` scoped to the repo's `CLAUDE.md`, `AGENTS.md` and `.claude/skills/`. The target model is the current Claude generation. It produces a report and a proposed diff.

On top of what it looks for, cut what the code shows quickly: architecture summaries, walkthroughs of code, inventories, version lists, calendar chores. Keep gotchas, commands, traps and conventions, and link to the repo's docs for depth.

Where the audit and Jason's rules disagree, his win. The audit leaves working duplicates alone; here, one fact gets one home (step 4).

## 3. Verify every claim you keep

Check each kept claim against the code: line numbers, doc links, defaults, commands. Stale ones turn up every time. Fix or cut them.

## 4. Sweep the journal and dedupe

If the repo has `.private-journal/`, have an Opus agent read it and propose items worth keeping, each with a target and checked against current code. Targets:

- repo facts teammates need: `AGENTS.md` (or `CLAUDE.md` if the repo has no `AGENTS.md`)
- facts shared across f500 repos: `~/src/f500/CLAUDE.md` (it is the vault note `f500-claude-md`, symlinked)
- Jason's working preferences: `~/.claude/CLAUDE.md`
- machine-local or session knowledge: this repo's Claude memory
- reference and reasoning: the vault

Spot-check the claims that matter before moving anything. Then move each fact into place and delete the other copies: memory, journal, scratch notes in `~/Downloads`. Once swept, the journal goes to the Trash, with Jason's OK.

## 5. Act on what the sweep finds

Fix wrong docs directly. File real bugs as Forgejo issues, not notes.

## 6. Hand back

One numbered list of decisions for Jason, each with a recommendation: audit hunks to take or skip, journal items and their targets, anything touching another person's repo. Then update the per-repo notes in the vault note.
