#!/usr/bin/env bash
# Claude Code setup script — installs Rust cargo tools via cargo-binstall.
# This runs automatically at the start of each Claude Code session.

set -euo pipefail

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

# Conditional tools — installed only when their framework/library is detected
REPO_ROOT="$(git rev-parse --show-toplevel)"

if grep -q 'dioxus' "$REPO_ROOT/Cargo.toml" 2>/dev/null; then
    if ! command -v dx &>/dev/null; then
        echo "==> Dioxus detected in Cargo.toml — installing dioxus-cli..."
        curl -sSL https://dioxus.dev/install.sh | bash
    else
        echo "==> Dioxus detected — dx already installed."
    fi
fi

echo "==> Setup complete."
