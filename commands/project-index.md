---
description: Create or update PROJECT_INDEX.md (tree + per-file descriptions) and wire it into all detected agent context files
---

Use the `project-indexer` skill to generate or update the project index for the current working directory.

Behavior:
- If `PROJECT_INDEX.md` does not exist at the repo root → full build.
- If it exists → incremental update (re-describe only changed files since last indexed commit/mtime).
- Honor `.gitignore`, `.claudeignore`, and `.aiignore`.
- Wire the `<!-- project-indexer:start -->` block into every detected agent context file: `CLAUDE.md`, `AGENTS.md`, `GEMINI.md`, `.cursor/rules/project-index.mdc`, `.windsurf/rules/project-index.md`, `.github/copilot-instructions.md`, `.clinerules/project-index.md`.
- If no agent context file exists, create `AGENTS.md` as a universal fallback.

After finishing, report:
- File count indexed
- New vs updated vs unchanged count
- Which agent context files were created or updated
