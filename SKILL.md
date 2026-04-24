---
name: project-indexer
description: Use when the user asks to "index this project", "map the codebase", "generate a project index", "create PROJECT_INDEX.md", "refresh/update the project index", or wants LLMs to understand the codebase layout without using Glob/Grep every turn. Also use when navigating an unfamiliar repo where file search is expensive and a structured index would cut tool calls. Always trigger when the user mentions indexing, cataloging, summarizing, or documenting a project's file structure — even phrased casually.
---

# Project Indexer

Generate and maintain `.claude/PROJECT_INDEX.md` — a tree of the project with a one-line description per file. Wire it into the project's `CLAUDE.md` via `@` import so future Claude sessions get structural context for free, eliminating most `Glob`/`Grep`/`find` calls.

## Why this matters

Every `Glob`/`Grep` call burns tokens and latency. When the model knows the project layout from a single import, it jumps straight to the right file. The index also becomes a living document of the codebase — reviewing it surfaces dead files, unclear naming, and missing coverage.

## Output format

`.claude/PROJECT_INDEX.md`:

```markdown
# Project Index

_Last updated: 2026-04-18 (mode: full | incremental)_
_Root: /abs/path/to/project_
_Files indexed: 87_

<!-- DO NOT EDIT MANUALLY. Regenerate via: "update project index" or "/project-indexer" -->

## Tree

\`\`\`
src/
  main/
    ipc.ts
    index.ts
  renderer/
    App.tsx
    components/
      MainPanel.tsx
      Sidebar.tsx
package.json
tsconfig.json
\`\`\`

## Files

### `src/main/ipc.ts`
IPC handlers for workspaces, memories, skills, agents, MCP, plugins, git sync, project init.

### `src/main/index.ts`
Electron main process entry — creates BrowserWindow, wires native menu, registers IPC.

### `src/renderer/App.tsx`
Root React component — renders tool switcher, sidebar, main panel; global hotkeys.

...
```

Keep each file description to **one concrete line** describing what the file does, not what it is. "Exports helper to parse git status" beats "Helper file".

## Two modes

### Manual mode (on request)

Triggered by phrases like "index this project", "update project index", "refresh the index", or explicit `/project-indexer` invocation.

### Auto mode (via hook)

A PostToolUse hook on `Write|Edit` tools regenerates the index when files change. The hook calls `scripts/auto_update.sh` which:
1. Debounces (skips if last update <60s ago)
2. Checks if `.claude/PROJECT_INDEX.md` exists (else skip — auto only refreshes, never creates)
3. Runs incremental update in the background

To enable auto mode, run setup once: follow the "Enable auto mode" section below.

## Process

### Step 1: Determine scope

Ignore patterns (union):
- Everything in `.gitignore` at project root
- Everything in `.claudeignore` at project root (if exists)
- Always ignore: `.git/`, `.DS_Store`, `*.lock`, `*.log`, `__pycache__/`, `.pytest_cache/`, `.next/`, `.turbo/`, `.cache/`, `*.min.js`, `*.min.css`
- Binary files (detect via extension list: `.png .jpg .jpeg .gif .ico .webp .pdf .woff .woff2 .ttf .otf .eot .mp4 .mp3 .wav .zip .tar .gz .bz2 .7z .dmg .exe .bin .so .dylib .dll .ipa .apk`)

Use `git ls-files --cached --others --exclude-standard` as the source of truth when inside a git repo — it already honors `.gitignore`. Then subtract `.claudeignore` matches and binary extensions.

When not in a git repo, walk the filesystem manually respecting the ignore rules above.

### Step 2: Detect mode

- **Full rebuild** when: no existing `PROJECT_INDEX.md`, or user says "rebuild" / "regenerate from scratch", or the index header is older than 30 days.
- **Incremental** otherwise: reuse existing descriptions, update only changed files.

For incremental, determine changed files via (in order of preference):
1. `git diff --name-only <last-indexed-commit> HEAD` + uncommitted `git status --porcelain` — if the previous index recorded a commit SHA
2. File `mtime > index_mtime` — fallback when no SHA stored

Read the first 20 lines of the existing `PROJECT_INDEX.md` to extract the stored commit SHA (stored as HTML comment `<!-- indexed-at-sha: abc1234 -->`).

### Step 3: Describe each file

For each file to index:
1. Read the file (cap at ~300 lines — enough for imports, main exports, top-level comments)
2. Write a one-line description focused on what the file **does**, not its type

Description rules:
- One sentence, ≤120 characters
- Present tense, active voice
- Name the primary export/purpose: "Exports X", "Renders Y", "Handles Z"
- For config files: state what's configured ("TypeScript strict mode + path aliases")
- For test files: name the unit under test ("Unit tests for `parseGitStatus`")
- For docs: first paragraph summary
- Skip trivial files (`.gitignore`, `.env.example`) with a short neutral line

**Parallelize** file reads when possible — for large projects use concurrent reads via subagents or Promise.all patterns. Batch in groups of ~20 to avoid context bloat.

### Step 4: Build the tree

Produce a collapsed directory tree using 2-space indent. Sort directories first, then files, alphabetically within each group. Use trailing `/` for dirs.

### Step 5: Write the index

Write `.claude/PROJECT_INDEX.md` with:
1. Header (timestamp, root, file count, current git SHA if available)
2. `## Tree` section with fenced code block
3. `## Files` section with `### \`path\`` headings + descriptions

Record the current `git rev-parse HEAD` inside an HTML comment for incremental detection next time.

### Step 6: Wire into `CLAUDE.md`

Manage a marked block so re-runs are idempotent:

```markdown
<!-- project-indexer:start -->
## Project Index

See @.claude/PROJECT_INDEX.md for the full file tree with per-file descriptions. Consult it BEFORE running Glob/Grep/find — the index usually has what you need.
<!-- project-indexer:end -->
```

- If `CLAUDE.md` doesn't exist: create it with just this block.
- If it exists but has no marked block: append the block at the end after a blank line.
- If the block exists: replace its contents in place (preserve surrounding content).

Never touch content outside the marked block.

## Enable auto mode

Hook setup is opt-in — the user must explicitly ask ("enable auto mode" / "set up auto indexing"). When asked:

1. Confirm the project has a `CLAUDE.md` or a `.claude/` dir (else bail — don't want auto-updates on random dirs).
2. Add to the project's `.claude/settings.json`:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          { "type": "command", "command": "bash ~/.claude/skills/project-indexer/scripts/auto_update.sh \"$CLAUDE_PROJECT_DIR\" &" }
        ]
      }
    ]
  }
}
```

The trailing `&` detaches the process so hook execution doesn't block the tool. The script itself handles debouncing + skip-if-missing.

3. Write `scripts/auto_update.sh` that:
   - Takes project root as arg
   - Exits if `.claude/PROJECT_INDEX.md` missing
   - Exits if mtime of that file is <60s old (debounce)
   - Touches a lock file, runs incremental reindex via `claude -p "update the project index"`, releases lock

Disable: remove the hook block from `.claude/settings.json`.

## Quick reference

| User says | Action |
|---|---|
| "index this project" / "/project-indexer" | Full rebuild if missing, else incremental |
| "update the project index" / "refresh index" | Incremental update |
| "rebuild the index from scratch" | Full rebuild (ignore existing descriptions) |
| "enable auto mode" / "auto-update the index" | Write hook into `.claude/settings.json` |
| "disable auto mode" | Remove hook |

## Common mistakes

- **Describing files as nouns ("A helper file")** — state what it DOES. "Parses git porcelain output into structured diff entries."
- **Skipping `.gitignore`** — don't index `node_modules`. Always start from `git ls-files` inside a repo.
- **Editing outside the marked block in CLAUDE.md** — preserve user's handwritten content.
- **Over-describing trivial files** — `.gitignore` needs no novel. A blank line or "Standard Node.js gitignore" is fine.
- **Rewriting unchanged descriptions on incremental runs** — reuse them verbatim. Only re-describe changed files.
- **Blocking on auto-mode hooks** — background the script; never make the user wait for an index update.

## Edge cases

- **Monorepos** — index the root; don't recurse into nested `.git` dirs.
- **Submodules** — list the submodule path as a single entry with its remote URL as the description, don't descend.
- **Very large files (>2000 lines)** — read only first + last 50 lines for description.
- **Generated files checked in** (e.g., `.gen.ts`, `pnpm-lock.yaml` — usually gitignored but some projects commit them): description = "Generated — do not edit".
- **Symlinks** — follow once, describe target; note `(symlink → target)` in the description.
