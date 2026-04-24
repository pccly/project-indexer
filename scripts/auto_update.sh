#!/usr/bin/env bash
# Auto-update project index. Called by PostToolUse hook.
# Usage: auto_update.sh <project_root>
# Debounces: skips if index updated <60s ago. Exits silently if index missing.

set -u
PROJECT_ROOT="${1:-}"
if [ -z "$PROJECT_ROOT" ] || [ ! -d "$PROJECT_ROOT" ]; then exit 0; fi

INDEX="$PROJECT_ROOT/PROJECT_INDEX.md"
LOCK="$PROJECT_ROOT/.project-index.lock"

# Only refresh if the index already exists. Auto mode never creates.
[ -f "$INDEX" ] || exit 0

# Debounce: skip if modified <60s ago
if command -v stat >/dev/null 2>&1; then
  if [ "$(uname)" = "Darwin" ]; then
    MTIME=$(stat -f %m "$INDEX" 2>/dev/null || echo 0)
  else
    MTIME=$(stat -c %Y "$INDEX" 2>/dev/null || echo 0)
  fi
  NOW=$(date +%s)
  if [ $((NOW - MTIME)) -lt 60 ]; then exit 0; fi
fi

# Single-flight lock
if [ -f "$LOCK" ]; then
  # Stale lock? Older than 5 min, kill it.
  if [ "$(uname)" = "Darwin" ]; then
    LOCK_MTIME=$(stat -f %m "$LOCK" 2>/dev/null || echo 0)
  else
    LOCK_MTIME=$(stat -c %Y "$LOCK" 2>/dev/null || echo 0)
  fi
  if [ $(( $(date +%s) - LOCK_MTIME )) -lt 300 ]; then exit 0; fi
fi

touch "$LOCK"
trap 'rm -f "$LOCK"' EXIT

# Run incremental update via claude -p. Background-friendly (caller also backgrounds us with &).
cd "$PROJECT_ROOT" || exit 0
if command -v claude >/dev/null 2>&1; then
  claude -p "Use the project-indexer skill to update the project index (incremental mode)." \
    >/dev/null 2>&1 || true
fi
