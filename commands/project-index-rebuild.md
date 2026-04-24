---
description: Force full rebuild of PROJECT_INDEX.md, discarding existing descriptions
---

Use the `project-indexer` skill in FULL REBUILD mode for the current working directory.

- Ignore any existing `PROJECT_INDEX.md` contents — re-describe every file from scratch.
- Still honor `.gitignore`, `.claudeignore`, and `.aiignore`.
- Re-wire the `<!-- project-indexer:start -->` block in every detected agent context file (`CLAUDE.md`, `AGENTS.md`, `GEMINI.md`, Cursor rules, Windsurf rules, Copilot instructions, Cline rules).

Report the file count, any files that couldn't be read, and which context files were updated.
