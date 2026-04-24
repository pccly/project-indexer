---
description: Force full rebuild of .claude/PROJECT_INDEX.md, discarding existing descriptions
---

Use the `project-indexer` skill in FULL REBUILD mode for the current working directory.

- Ignore any existing `.claude/PROJECT_INDEX.md` contents — re-describe every file from scratch.
- Still honor `.gitignore` and `.claudeignore`.
- Re-wire the `<!-- project-indexer:start -->` block in `./CLAUDE.md`.

Report the file count and any files that couldn't be read.
