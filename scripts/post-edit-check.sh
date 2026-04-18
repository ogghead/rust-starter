#!/usr/bin/env bash
# PostToolUse hook: runs cargo check after editing .rs files.
# Receives tool use JSON on stdin. Exits 0 always for non-.rs files.
# Outputs diagnostics so Claude sees compiler errors immediately.

set -euo pipefail

INPUT=$(cat)

FILE_PATH=$(echo "$INPUT" | grep -oP '"file_path"\s*:\s*"[^"]*"' | head -1 | sed 's/.*"file_path"\s*:\s*"\([^"]*\)".*/\1/')

if [[ "$FILE_PATH" != *.rs ]]; then
  exit 0
fi

cd "$(git rev-parse --show-toplevel)"

echo "Running cargo check after editing $FILE_PATH..."
if cargo check --message-format=short 2>&1; then
  echo "cargo check passed"
else
  echo "cargo check FAILED - fix errors before continuing"
  exit 1
fi
