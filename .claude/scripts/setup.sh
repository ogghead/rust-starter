#!/usr/bin/env bash
# Claude Code setup script — installs Rust cargo tools via cargo-binstall.
# This runs automatically at the start of each Claude Code session.

set -euo pipefail

# Install GitHub CLI if not already present
if ! command -v gh &>/dev/null; then
    echo "==> Installing GitHub CLI..."
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        | tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    apt-get update -qq && apt-get install -y -qq gh > /dev/null 2>&1
    echo "    gh $(gh --version | head -1) installed."
else
    echo "==> GitHub CLI already installed."
fi

echo "==> Installing Rust toolchain components..."
rustup show active-toolchain || rustup default stable

# Install cargo-binstall if not already present
if ! command -v cargo-binstall &>/dev/null; then
    echo "==> Installing cargo-binstall..."
    curl -L --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.sh | bash
fi

# Tools required by this project (see CLAUDE.md)
TOOLS=(
    cargo-nextest      # Preferred test runner
    cargo-deny         # Dependency audit (licenses, advisories, bans)
    cargo-llvm-cov     # Code coverage
    cargo-machete      # Unused dependency detection
    zizmor             # GitHub Actions security linter
)

echo "==> Installing cargo tools via cargo-binstall..."
for tool in "${TOOLS[@]}"; do
    # Strip inline comments
    tool="${tool%%#*}"
    tool="${tool// /}"
    if ! command -v "$tool" &>/dev/null; then
        echo "    Installing $tool..."
        cargo binstall --no-confirm "$tool"
    else
        echo "    $tool already installed."
    fi
done

# Install shellcheck (actionlint uses it for deeper script analysis)
if ! command -v shellcheck &>/dev/null; then
    echo "==> Installing shellcheck..."
    apt-get install -y -qq shellcheck > /dev/null 2>&1 || echo "    WARNING: could not install shellcheck"
fi

# Install actionlint (Go binary — GitHub Actions workflow linter)
export PATH="$HOME/go/bin:$HOME/.local/bin:$PATH"
if ! command -v actionlint &>/dev/null; then
    echo "==> Installing actionlint..."
    if command -v go &>/dev/null; then
        go install github.com/rhysd/actionlint/cmd/actionlint@latest
    else
        echo "    WARNING: Go not available, skipping actionlint install"
    fi
else
    echo "==> actionlint already installed."
fi

# Conditional tools — installed only when their framework/library is detected
REPO_ROOT="$(git rev-parse --show-toplevel)"

if grep -q 'dioxus' "$REPO_ROOT/Cargo.toml" 2>/dev/null; then
    # Extract dioxus version from Cargo.toml (handles both 'dioxus = "0.7"' and 'dioxus = { version = "0.7", ... }')
    DIOXUS_VERSION=$(grep -oP 'dioxus\s*=\s*(?:"([^"]+)"|\{[^}]*version\s*=\s*"([^"]+)")' "$REPO_ROOT/Cargo.toml" | grep -oP '"\K[^"]+' | head -1)

    NEEDS_INSTALL=false
    if ! command -v dx &>/dev/null; then
        NEEDS_INSTALL=true
    elif [ -n "$DIOXUS_VERSION" ]; then
        INSTALLED_VERSION=$(dx --version 2>/dev/null | grep -oP '[0-9]+\.[0-9]+\.[0-9]+' || echo "")
        if [ "$INSTALLED_VERSION" != "$DIOXUS_VERSION" ]; then
            echo "==> Dioxus CLI version mismatch (installed: ${INSTALLED_VERSION:-unknown}, needed: $DIOXUS_VERSION)"
            NEEDS_INSTALL=true
        fi
    fi

    if [ "$NEEDS_INSTALL" = true ] && [ -n "$DIOXUS_VERSION" ]; then
        echo "==> Dioxus detected in Cargo.toml — installing dioxus-cli v${DIOXUS_VERSION}..."
        curl -sSL https://dioxus.dev/install.sh | sh -s -- "dx-v${DIOXUS_VERSION}"
    elif [ "$NEEDS_INSTALL" = true ]; then
        echo "==> Dioxus detected in Cargo.toml — installing dioxus-cli (latest)..."
        curl -sSL https://dioxus.dev/install.sh | bash
    else
        echo "==> Dioxus detected — dx already installed (v${INSTALLED_VERSION})."
    fi
fi

# Install pre-commit hook (idempotent — uses symlink)
echo "==> Installing pre-commit hook..."
ln -sf "$REPO_ROOT/scripts/pre-commit" "$REPO_ROOT/.git/hooks/pre-commit"
chmod +x "$REPO_ROOT/scripts/pre-commit"

# Detect open PR for current branch so Claude can subscribe to activity
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || true)
if [ -n "$CURRENT_BRANCH" ] && command -v gh &>/dev/null; then
    PR_INFO=$(gh pr list --head "$CURRENT_BRANCH" --json number,url --jq '.[0] | "PR #\(.number) \(.url)"' 2>/dev/null || true)
    if [ -n "$PR_INFO" ]; then
        echo "==> Open $PR_INFO found for branch $CURRENT_BRANCH. Subscribe to PR activity to watch for CI failures and review comments."
    fi
fi

echo "==> Setup complete."
