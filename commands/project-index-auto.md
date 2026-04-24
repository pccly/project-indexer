---
description: Enable or disable auto-update of the project index via a PostToolUse hook
argument-hint: on | off
---

Target state: $ARGUMENTS (expect `on` or `off`).

Use the `project-indexer` skill to manage the auto-update hook for the current project.

**If `on`:**
1. Require that `.claude/PROJECT_INDEX.md` exists in the current project (if not, run the index creation first).
2. Merge into `.claude/settings.json` (create if missing) a PostToolUse hook with matcher `Write|Edit` running:
   ```
   bash ~/.claude/skills/project-indexer/scripts/auto_update.sh "$CLAUDE_PROJECT_DIR" &
   ```
   Preserve any existing hooks — do not overwrite the full array.
3. Confirm to the user that auto mode is enabled and note the 60s debounce.

**If `off`:**
1. Remove ONLY the project-indexer hook entry from `.claude/settings.json` (leave other hooks intact).
2. Confirm auto mode is disabled.

**If no argument:**
- Read the current state from `.claude/settings.json` and report whether auto mode is on or off.
