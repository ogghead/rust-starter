# {{project-name}}

> {{description}}

## Prerequisites

- [Rust stable](https://rustup.rs/) (see `rust-toolchain.toml` for pinned version)

## Quick Start

```sh
cargo run
```

## Commands

| Command | Purpose |
|---------|---------|
| `cargo check` | Fast type-check |
| `cargo build` | Compile debug binary |
| `cargo build --release` | Compile optimized binary |
| `cargo test --doc && cargo nextest run` | Run all tests |
| `cargo clippy -- -D warnings` | Lint (warnings = errors) |
| `cargo fmt` | Format code |
| `cargo deny check` | Audit dependencies |
| `cargo llvm-cov nextest` | Run tests with coverage |

## Before Committing

```sh
cargo fmt && cargo clippy -- -D warnings && cargo test --doc && cargo nextest run
```
