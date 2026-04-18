#!/usr/bin/env bash
# PostToolUse hook: runs cargo check after editing .rs files,
# actionlint + zizmor after editing workflow YAML files.
# Receives tool use JSON on stdin. Exits 0 for irrelevant files.

set -euo pipefail

INPUT=$(cat)

FILE_PATH=$(echo "$INPUT" | grep -oP '"file_path"\s*:\s*"[^"]*"' | head -1 | sed 's/.*"file_path"\s*:\s*"\([^"]*\)".*/\1/')

export PATH="$HOME/go/bin:$HOME/.local/bin:$PATH"
cd "$(git rev-parse --show-toplevel)"

# Lint GitHub Actions workflows when editing YAML files
if [[ "$FILE_PATH" == */.github/workflows/*.yml || "$FILE_PATH" == */.github/workflows/*.yaml ]]; then
  if command -v actionlint &>/dev/null; then
    echo "Running actionlint on $FILE_PATH..."
    if actionlint "$FILE_PATH" 2>&1; then
      echo "actionlint passed"
    else
      echo "actionlint FAILED - fix workflow errors before continuing"
      exit 1
    fi
  fi
  if command -v zizmor &>/dev/null; then
    echo "Running zizmor on $FILE_PATH..."
    if zizmor "$FILE_PATH" 2>&1; then
      echo "zizmor passed"
    else
      echo "zizmor FAILED - fix security issues before continuing"
      exit 1
    fi
  fi
  exit 0
fi

# Only run cargo check for .rs files
if [[ "$FILE_PATH" != *.rs ]]; then
  exit 0
fi

echo "Running cargo check after editing $FILE_PATH..."
if cargo check --message-format=short 2>&1; then
  echo "cargo check passed"
else
  echo "cargo check FAILED - fix errors before continuing"
  exit 1
fi
