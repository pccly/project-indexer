---
name: project-indexer
description: Use when the user asks to "index this project", "map the codebase", "generate a project index", "create PROJECT_INDEX.md", "refresh/update the project index", or wants any AI coding agent (Claude Code, Cursor, Codex, Gemini CLI, Windsurf, Copilot, Cline, etc.) to understand the codebase layout without using Glob/Grep every turn. Also use when navigating an unfamiliar repo where file search is expensive and a structured index would cut tool calls. Always trigger when the user mentions indexing, cataloging, summarizing, or documenting a project's file structure — even phrased casually.
---

# Project Indexer

Generate and maintain `PROJECT_INDEX.md` at the repo root — a tree of the project with a one-line description per file. Wire it into whichever AI-agent context file exists (`CLAUDE.md`, `AGENTS.md`, `GEMINI.md`, Cursor rules, Windsurf rules, Copilot instructions, etc.) so future sessions get structural context for free, eliminating most `Glob`/`Grep`/`find` calls.

## Why this matters

Every `Glob`/`Grep` call burns tokens and latency. When the agent knows the project layout from a single import, it jumps straight to the right file. The index also becomes a living document of the codebase — reviewing it surfaces dead files, unclear naming, and missing coverage.

## Output location

Write to **`PROJECT_INDEX.md` at the repo root**. This keeps the index harness-agnostic — every AI agent (and every human) can find it regardless of tool.

Do NOT write to `.claude/PROJECT_INDEX.md` or any other tool-specific directory. The index is shared across all agents.

## Output format

```markdown
# Project Index

_Last updated: 2026-04-24 (mode: full | incremental)_
_Root: /abs/path/to/project_
_Files indexed: 87_

<!-- DO NOT EDIT MANUALLY. Regenerate via: "update project index" or /project-index -->
<!-- indexed-at-sha: abc1234 -->

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

Triggered by phrases like "index this project", "update project index", "refresh the index", or explicit slash command.

### Auto mode (via hook) — harness-dependent

Auto mode requires a PostToolUse hook on file-write tools. **Only available on**:
- **Claude Code** — via `.claude/settings.json` `PostToolUse` hook
- **Codex** — via `.codex/hooks.json` (if the harness enables hooks)

Other harnesses (Cursor, Windsurf, Copilot, Gemini CLI, Cline) have no equivalent hook system — skip auto mode and run manually.

See "Enable auto mode" below for setup.

## Process

### Step 1: Determine scope

Ignore patterns (union) — files EXCLUDED from the index entirely:
- Everything in `.gitignore` at project root
- Everything in `.claudeignore` and/or `.aiignore` at project root (if exists)
- Always ignore: `.git/`, `.DS_Store`, `*.lock`, `*.log`, `__pycache__/`, `.pytest_cache/`, `.next/`, `.turbo/`, `.cache/`, `*.min.js`, `*.min.css`

**No-read** files — INCLUDED in the index but NEVER opened (description derived from filename/extension only, never from contents). This avoids burning tokens and latency on images and other binary/heavy assets:
- Images: `.png .jpg .jpeg .gif .ico .webp .svg .avif .bmp .tiff`
- Fonts: `.woff .woff2 .ttf .otf .eot`
- Media: `.mp4 .mp3 .wav .mov .webm .ogg .flac`
- Archives: `.zip .tar .gz .bz2 .7z .rar`
- Binaries / compiled: `.pdf .exe .bin .so .dylib .dll .dmg .ipa .apk .wasm .class .o .a`
- Data blobs > 1 MB regardless of extension (`.json`, `.csv`, `.parquet`, `.sqlite`, etc.)
- Any text file > 2000 lines — read only first 50 + last 50 lines (already covered in Edge cases)

For no-read files, write a generic one-liner from the filename + parent dir, e.g.:
- `assets/logo.png` → "PNG image asset."
- `fonts/Inter-Regular.woff2` → "WOFF2 font file."
- `data/users.sqlite` → "SQLite database blob."

Use `git ls-files --cached --others --exclude-standard` as the source of truth when inside a git repo — it already honors `.gitignore`. Then subtract `.claudeignore` / `.aiignore` matches. Do NOT subtract no-read extensions — they still appear in the tree.

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

1. **Check the no-read list first** (images, fonts, media, archives, binaries, >1 MB blobs). If matched, skip reading entirely — derive the description from filename + extension only. Do NOT use Read, cat, or any content-loading tool on these files.

2. **Default path — comments + signatures only.** This is the primary fast path for ALL code files regardless of size. Do NOT full-read first.
   - **Leading doc comment**: `head -50 <file>` (covers module docstrings, JSDoc, `"""..."""`, `/** ... */`, top-level `//` banner).
   - **Signatures**: `grep -nE '^(export |export default |def |async def |class |function |async function |interface |type |const [A-Z]|let [A-Z]|var [A-Z]|pub |pub fn |fn |impl |struct |enum |trait |func |protocol )' <file> | head -60`
   - Union of the two is usually enough to write an accurate one-liner. Skip bodies, loops, inline logic.
   - For config/markdown/JSON/YAML: `head -50 <file>` alone is enough — no signature grep needed.

3. **Escalate only if signatures-only is too thin** — e.g. file is a single default-export function with no signatures at top, a flat script with no declarations, or a pure data file where the "what" lives in values. Then Read the file with a 300-line cap. Last resort only — adds real latency.

4. Write a one-line description focused on what the file **does**, not its type.

**Reading more when needed**: the fast path above is the DEFAULT budget. If the signature+comment scan still leaves you with a vague description, do a targeted follow-up: Read with an offset aimed at a symbol you spotted, or grep a specific identifier. Prefer surgical follow-ups over full re-reads.

Description rules:
- One sentence, ≤120 characters
- Present tense, active voice
- Name the primary export/purpose: "Exports X", "Renders Y", "Handles Z"
- For config files: state what's configured ("TypeScript strict mode + path aliases")
- For test files: name the unit under test ("Unit tests for `parseGitStatus`")
- For docs: first paragraph summary
- Skip trivial files (`.gitignore`, `.env.example`) with a short neutral line

**Parallelize aggressively — this is MANDATORY, not optional:**

- **≤50 files** — batch reads in groups of 20 via a single message with 20 parallel Read tool calls. Never read files one at a time in sequence.
- **>50 files** — dispatch subagents (Explore type). Split the file list into chunks of ~30 files per subagent. Each subagent returns `{path: description}` pairs. Merge results in the main thread.
  - Prompt template for each subagent: "For each file, generate a one-line description (≤120 chars, present tense, naming the primary export/purpose). DEFAULT method: `head -50 <file>` + `grep -nE '^(export|def|class|function|interface|type|pub|fn|async|impl|struct|enum|trait)' <file> | head -60`. Only full-read (cap 300 lines) when signatures alone are too thin. Return `path: description` per line. Files: [list]."
  - Run subagents in parallel via a single message with multiple Agent tool calls.
- Reading files one-by-one on a repo of 100+ files is a bug. Always batch.

### Step 4: Build the tree

Produce a collapsed directory tree using 2-space indent. Sort directories first, then files, alphabetically within each group. Use trailing `/` for dirs.

### Step 5: Write the index

Write `PROJECT_INDEX.md` at the repo root with:
1. Header (timestamp, root, file count, mode)
2. HTML comment recording current `git rev-parse HEAD` for incremental detection next time
3. `## Tree` section with fenced code block
4. `## Files` section with `### \`path\`` headings + descriptions

### Step 6: Wire into agent context files

Detect which agent context files exist at the repo root (and tool-specific subdirs). For EACH detected file, manage a marked block so re-runs are idempotent.

**Block content** (same text in every file):

```markdown
<!-- project-indexer:start -->
## Project Index

See `PROJECT_INDEX.md` for the full file tree with per-file descriptions. Consult it BEFORE running Glob/Grep/find — the index usually has what you need.
<!-- project-indexer:end -->
```

On Claude Code specifically, use the `@` import form instead so the index loads into context automatically:

```markdown
<!-- project-indexer:start -->
## Project Index

See @PROJECT_INDEX.md for the full file tree with per-file descriptions. Consult it BEFORE running Glob/Grep/find.
<!-- project-indexer:end -->
```

**Target files (wire into every one that exists, create any that are clearly indicated)**:

| Harness | File | Create if missing? |
|---|---|---|
| Claude Code | `CLAUDE.md` | Yes (if `.claude/` dir exists) |
| Codex / Amp / any AGENTS.md agent | `AGENTS.md` | Yes (if no `CLAUDE.md` exists — acts as universal fallback) |
| Gemini CLI | `GEMINI.md` | Only if `.gemini/` dir exists |
| Cursor | `.cursor/rules/project-index.mdc` | Only if `.cursor/` dir exists |
| Windsurf | `.windsurf/rules/project-index.md` | Only if `.windsurf/` dir exists |
| Copilot | `.github/copilot-instructions.md` | Only if `.github/` dir exists |
| Cline | `.clinerules/project-index.md` | Only if `.clinerules/` dir exists |

**Rules**:
- Never create a tool's context file unless its config dir (`.claude/`, `.cursor/`, etc.) already exists — don't silently opt the user into tools they aren't using.
- **Exception**: If NO agent file exists at all, create `AGENTS.md` at the root as a universal fallback. Most agents (Codex, Amp, opencode, Cursor via rules, etc.) honor `AGENTS.md`.
- When appending to an existing file, add a blank line before the marked block.
- When the block already exists, replace its contents in place. Never touch content outside the marked block.
- For Cursor's `.mdc` files, prepend minimal frontmatter if the file is being created:
  ```
  ---
  description: Project file index
  globs: ["**/*"]
  alwaysApply: true
  ---
  ```

### Step 7: Report

Tell the user which files were written/updated. Example:
> Indexed 87 files. Wrote `PROJECT_INDEX.md`. Updated `CLAUDE.md`, `AGENTS.md`. Created `.cursor/rules/project-index.mdc`.

## Enable auto mode

**Claude Code**: Merge into `.claude/settings.json` (preserve existing hooks):
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

**Codex**: Merge into `.codex/hooks.json` using `SessionStart` or `PostToolCall` hook (syntax varies — check Codex docs). Point to the same `auto_update.sh`, passing the project root.

**Other harnesses**: No hook system available. Run `/project-index` manually after significant changes, or ask the agent "update the project index".

Disable: remove the hook block from the relevant settings file.

The script itself handles debouncing (60s) + skip-if-missing + single-flight lock.

## Quick reference

| User says | Action |
|---|---|
| "index this project" / `/project-index` | Full rebuild if missing, else incremental |
| "update the project index" / "refresh index" | Incremental update |
| "rebuild the index from scratch" | Full rebuild (ignore existing descriptions) |
| "enable auto mode" / "auto-update the index" | Write hook (Claude Code / Codex only) |
| "disable auto mode" | Remove hook |

## Common mistakes

- **Opening images/binaries to describe them** — never Read `.png`, `.woff2`, `.pdf`, etc. Describe from filename only. Reading images burns huge time/tokens for zero signal.
- **Writing index to `.claude/PROJECT_INDEX.md`** — belongs at repo root so all agents see it.
- **Reading files sequentially** — kills indexing speed. Always batch in parallel (20 Reads per message) or dispatch subagents for >50 files.
- **Describing files as nouns ("A helper file")** — state what it DOES.
- **Skipping `.gitignore`** — don't index `node_modules`. Always start from `git ls-files` inside a repo.
- **Creating context files for unused tools** — only touch `.cursor/`, `.gemini/`, etc. if the directory already exists.
- **Overwriting the whole `CLAUDE.md` / `AGENTS.md`** — only modify the `<!-- project-indexer:start -->` block.
- **Rewriting unchanged descriptions on incremental runs** — reuse them verbatim. Only re-describe changed files.
- **Enabling auto mode on tools without hooks** — Cursor/Windsurf/Copilot have no hook system; stop and tell the user.
- **Blocking on auto-mode hooks** — background the script; never make the user wait for an index update.

## Edge cases

- **Monorepos** — index the root; don't recurse into nested `.git` dirs.
- **Submodules** — list the submodule path as a single entry with its remote URL as the description, don't descend.
- **Any text file** — default to `head -50` (leading comment) + `grep` for signatures. Full-read only as an escalation when signatures are too thin. Never full-read by default.
- **Generated files checked in** (e.g., `.gen.ts`, `pnpm-lock.yaml` — usually gitignored but some projects commit them): description = "Generated — do not edit".
- **Symlinks** — follow once, describe target; note `(symlink → target)` in the description.
- **Multiple agent files coexisting** (`CLAUDE.md` AND `AGENTS.md` both present) — wire the block into both; they serve different agents.
