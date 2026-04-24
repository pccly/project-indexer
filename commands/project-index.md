---
description: Create or update .claude/PROJECT_INDEX.md with tree + per-file descriptions, and wire into CLAUDE.md
---

Use the `project-indexer` skill to generate or update the project index for the current working directory.

Behavior:
- If `.claude/PROJECT_INDEX.md` does not exist → full build.
- If it exists → incremental update (re-describe only changed files since last indexed commit/mtime).
- Honor `.gitignore` and `.claudeignore`.
- Wire `./CLAUDE.md` to `@.claude/PROJECT_INDEX.md` inside the `<!-- project-indexer:start -->` / `<!-- project-indexer:end -->` block (create `CLAUDE.md` if missing).

After finishing, report:
- File count indexed
- New vs updated vs unchanged count
- Whether CLAUDE.md was created or updated
