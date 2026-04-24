---
description: Enable or disable auto-update of the project index via a PostToolUse hook (Claude Code + Codex only)
argument-hint: on | off
---

Target state: $ARGUMENTS (expect `on` or `off`).

Use the `project-indexer` skill to manage the auto-update hook for the current project.

**Harness support**: auto mode only works on Claude Code (via `.claude/settings.json`) and Codex (via `.codex/hooks.json`). Cursor, Windsurf, Copilot, Gemini CLI, and Cline have no hook system — bail with a friendly message telling the user to run `/project-index` manually after changes.

**If `on`:**
1. Require that `PROJECT_INDEX.md` exists at the repo root (if not, run the index creation first).
2. Detect harness:
   - `.claude/` dir present → merge a `PostToolUse` hook into `.claude/settings.json`:
     ```
     bash ~/.claude/skills/project-indexer/scripts/auto_update.sh "$CLAUDE_PROJECT_DIR" &
     ```
   - `.codex/` dir present → merge a hook into `.codex/hooks.json` pointing to the same script.
   - Neither → tell the user auto mode isn't available on their harness.
3. Preserve any existing hooks — do not overwrite the full array.
4. Confirm to the user that auto mode is enabled and note the 60s debounce.

**If `off`:**
1. Remove ONLY the project-indexer hook entry from the relevant settings file (leave other hooks intact).
2. Confirm auto mode is disabled.

**If no argument:**
- Read the current state from `.claude/settings.json` and/or `.codex/hooks.json` and report whether auto mode is on or off.
