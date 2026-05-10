#!/usr/bin/env bash
# install-hook.sh — install pre-commit-drift.sh into .git/hooks/pre-commit
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
HOOK="$REPO_ROOT/.git/hooks/pre-commit"
TARGET="../../plugins/chittyagent-dispatch/scripts/pre-commit-drift.sh"

if [ -e "$HOOK" ] && [ ! -L "$HOOK" ]; then
  echo "refusing to overwrite existing non-symlink hook: $HOOK" >&2
  echo "back it up or delete it, then re-run." >&2
  exit 1
fi

ln -snf "$TARGET" "$HOOK"
chmod +x "$REPO_ROOT/plugins/chittyagent-dispatch/scripts/pre-commit-drift.sh"
echo "[install-hook] linked $HOOK -> $TARGET"
