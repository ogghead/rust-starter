#!/usr/bin/env bash
# Installs git hooks for local development.
# Run once after cloning: ./scripts/install-hooks.sh

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
HOOK_DIR="$REPO_ROOT/.git/hooks"

ln -sf "$REPO_ROOT/scripts/pre-commit" "$HOOK_DIR/pre-commit"
chmod +x "$REPO_ROOT/scripts/pre-commit"

echo "Git hooks installed successfully."
