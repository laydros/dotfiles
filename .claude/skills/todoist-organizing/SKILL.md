---
name: todoist-organizing
description: Jason's organizing standard for Todoist. Use before creating, editing, completing, or reorganizing anything in Todoist, and before deciding whether something is a task, project, area, research, reference, or idea. Carries the label ceilings and the placeholder rule.
---

# Organizing Standard: kinds, Todoist, and ceilings

**The authority is the vault** (location per the shared CLAUDE.md), at `reference/organizing-standard.md` with the capture rules in `reference/salience-routing.md`. If the vault is reachable, read those and let them win over this summary. What follows is the condensed version for when it is not.

## Kind vs state

**Kind** is what a thing is. It is stable, and the folder or container says it. **State** is where it is right now and changes on its own; it is never written in the vault. Todoist owns state: tasks in `active` or `next` means live, only backlog means paused, no tasks means someday. A paused project is still a project, and paused for months is normal.

## The kinds

- **Task** — one outcome whose next step is always obvious from the last one. Duration does not decide it. Lives in Todoist.
- **Project** — an outcome with a finish line that needs a plan. Test: can it be marked done, and did you have to work out what the parts are? The plan lives in the vault or the repo, never in Todoist subtasks.
- **Area** — an ongoing responsibility with no finish line, only standards to keep. Areas nest and hold projects. A topic can be both in sequence: "set up DR" is a project, afterwards DR is an area.
- **Research** — findings toward a decision not yet made, waiting on an event. Lives in `research/`.
- **Reference** — settled knowledge. Never a task.
- **Idea** — a line, not a body of work. No action until picked up.

## The Todoist mapping

- Top-level project = **area** (Work, Personal, Pond, Lettie).
- Sub-project = a large **project** or a long-lived area under it (z3, WyDocs, DR).
- Section = a **phase or part** within that. This is where a project's plan becomes visible without becoming 200 tasks.
- Task = task. **Subtasks only when the checklist is known at creation and fits on one screen**; context goes in the description. Needing subtasks under subtasks means it is a project, and the plan moves to the vault or the repo.

## Labels carry state, not category

The category is already the project.

| Label | Meaning | Ceiling |
|---|---|---|
| `active` | being worked now | **3, across all of Todoist** |
| `next` | ready to pick up | **7** |
| `waiting` | blocked or deferred | none |

Domain labels (`work`, `dev`, `z3`, `home`, `nanoclaw`) are additive, for filtering. **Never put an `@` in a label name** — the API stores bare strings; the `@` is UI rendering only.

**Priority has no standard yet** (Jason, 2026-09-17). `p1` gets used occasionally for something genuinely urgent; `p2`-`p4` carry no agreed meaning, so existing values are not a signal. Leave priority alone unless he sets it, and do not infer a scheme from what is already there.

## The rule that keeps it small

Only the section currently being worked gets real tasks. **Every other section holds exactly one placeholder line** until it is reached. A placeholder must never carry `active` or `next` — it marks sequence, not work, and must not appear in the working view. Creating it with `isUncompletable: true` enforces that structurally.

## What not to do

- Do not create a task for something already captured in a plan document. **Point at the document.**
- Do not duplicate a plan into Todoist. The plan has one home.
- Do not create a new Todoist project for something that is a project under an existing area. Use a section.
- Do not conclude "there is no task for this" from a search of active tasks. **Completed tasks are invisible to that search** — check completed tasks over the relevant window first. The highest-value question in any review is "is this already done?"
- Do not add tasks opportunistically while doing other work. Filing is a deliberate act.
- Do not restructure beyond what is described here without asking.
