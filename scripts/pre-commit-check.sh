#!/usr/bin/env bash
# PreToolUse hook: runs full quality gates before git commit.
# Receives tool use JSON on stdin. Blocks the commit if checks fail.

set -euo pipefail

INPUT=$(cat)

COMMAND=$(echo "$INPUT" | grep -oP '"command"\s*:\s*"[^"]*"' | head -1 | sed 's/.*"command"\s*:\s*"\([^"]*\)".*/\1/')

if [[ "$COMMAND" != *"git commit"* ]]; then
  exit 0
fi

cd "$(git rev-parse --show-toplevel)"

echo "Pre-commit quality gate: running fmt + clippy + tests..."

echo "--- cargo fmt --check ---"
if ! cargo fmt -- --check 2>&1; then
  echo "Formatting check failed. Run 'cargo fmt' first."
  exit 1
fi
echo "Formatting OK"

echo "--- cargo clippy ---"
if ! cargo clippy -- -D warnings 2>&1; then
  echo "Clippy found warnings/errors. Fix them before committing."
  exit 1
fi
echo "Clippy OK"

echo "--- cargo test ---"
if ! cargo test 2>&1; then
  echo "Tests failed. Fix them before committing."
  exit 1
fi
echo "Tests OK"

echo "All pre-commit checks passed. Proceeding with commit."
