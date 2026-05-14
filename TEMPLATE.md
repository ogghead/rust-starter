# rust-starter

A Rust application starter template with strict lints, miette errors, tracing, CI, and coverage.

## What's Included

- **Error handling**: `miette` + `thiserror` with diagnostic codes and actionable help messages
- **Logging**: `tracing` + `tracing-subscriber` with `RUST_LOG` env filter
- **Strict lints**: Clippy pedantic + nursery + custom restriction lints (forbid unwrap/expect/panic/print/dbg/unsafe)
- **CI pipeline**: Format, clippy, tests (nextest), MSRV check, dependency audit (`cargo-deny`), unused dep detection (`cargo-machete`), code coverage (`cargo-llvm-cov`)
- **Coverage**: 90% threshold enforced in CI, HTML reports as artifacts
- **Profiles**: Optimized release (`lto`, `strip`, `panic=abort`) and dev (`split-debuginfo`)
- **Testing**: `pretty_assertions` + `insta` snapshot testing
- **Edition 2024** with MSRV 1.93

## Usage

```sh
cargo install cargo-generate
cargo generate --git https://github.com/ogghead/rust-starter --name my-project
```

> **Note:** This template requires [cargo-generate](https://cargo-generate.github.io/cargo-generate/).
> GitHub's "Use this template" button will **not** work — it copies files as-is without replacing
> template variables like `{{project-name}}`.

## After Generation

```sh
cd my-project
cargo fmt && cargo clippy -- -D warnings && cargo nextest run
```

See `CLAUDE.md` for full development conventions and `README.md` for project-specific docs.
