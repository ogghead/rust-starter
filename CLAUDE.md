# {{project-name}}

Rust application (edition 2024, MSRV 1.93, stable channel).

## Commands

| Command | Purpose |
|---------|---------|
| `cargo check` | Fast type-checking (use first, before build) |
| `cargo build` | Compile debug binary |
| `cargo build --release` | Compile optimized binary |
| `cargo run` | Build and run |
| `cargo nextest run` | Run unit/integration tests (preferred) |
| `cargo nextest run -E 'test(name)'` | Run a specific test |
| `cargo test --doc` | Run doc tests (nextest can't run these) |
| `cargo clippy -- -D warnings` | Lint (warnings = errors) |
| `cargo fmt` | Format code |
| `cargo fmt -- --check` | Check formatting without modifying |
| `cargo doc --open` | Build and open docs |
| `cargo deny check` | Audit dependencies (licenses, advisories, bans) |
| `cargo machete` | Detect unused dependencies |
| `cargo llvm-cov nextest` | Run tests with coverage (text summary) |
| `cargo llvm-cov nextest --html --open` | Coverage report in browser |
| `cargo llvm-cov nextest --lcov --output-path lcov.info` | Generate LCOV for editors |
| `cargo llvm-cov nextest --workspace --ignore-filename-regex 'src/main\.rs$' --fail-under-lines 90` | Enforce coverage threshold (matches CI) |
| `cargo llvm-cov clean` | Remove coverage artifacts |

## Workflow

Before committing, always run: `cargo fmt && cargo clippy -- -D warnings && cargo test`

A pre-commit hook automates this (format check, clippy, tests, and optionally `cargo deny check`). It is installed automatically by the Claude Code session start hook.

Coverage threshold is 90% line coverage, enforced in CI. `main.rs` is excluded from the threshold because it is a thin shim that cannot be unit tested. Install `cargo-llvm-cov` to check locally (the `llvm-tools` component is already in `rust-toolchain.toml`).

When the SessionStart hook reports an open PR for the current branch, use `subscribe_pr_activity` to watch for CI failures and review comments. Investigate each event and fix issues or ask the user if the fix is ambiguous.

## Architecture

```
src/
  main.rs          # Thin shim — calls lib::run()
  lib.rs           # Library root — run() entry point and module declarations
  error.rs         # Application error types (miette Diagnostic)
crates/            # Workspace crates (add new crates here)
tests/
  integration_test.rs  # Integration tests for run()
scripts/
  pre-commit           # Pre-commit hook (fmt, clippy, test, deny)
  post-edit-check.sh   # Claude Code hook: cargo check after .rs edits
  pre-commit-check.sh  # Claude Code hook: quality gate before git commit
.config/
  nextest.toml         # Test runner config (500ms slow-test timeout)
.claude/
  settings.json        # Claude Code session hooks
  scripts/
    setup.sh           # Auto-installs cargo tools at session start
.github/
  workflows/
    ci.yml             # Main CI: lint, test, MSRV, deny, coverage
    template-test.yml  # Validates cargo-generate template
  dependabot.yml       # Weekly updates for cargo & actions
```

`main.rs` is a one-line shim that calls `{{crate_name}}::run()`. All initialization and application logic lives in the library crate so it can be tested and covered.

### Workspace Layout

This project uses a Cargo workspace. The root `Cargo.toml` defines shared configuration
(`workspace.package`, `workspace.dependencies`, `workspace.lints`) and the root binary crate.
Add new library crates under `crates/`:

```sh
cargo init --lib crates/my-crate
```

Then in the new crate's `Cargo.toml`, inherit workspace config:

```toml
[package]
name = "my-crate"
version.workspace = true
edition.workspace = true
rust-version.workspace = true
license.workspace = true

[dependencies]
miette = { workspace = true }

[lints]
workspace = true
```

Use file-per-module (mod.rs is legacy). Prefer `foo.rs` for flat modules and `foo/` directory with named files for nested modules.

This repo doubles as a `cargo-generate` template. Template config is in `cargo-generate.toml`.

To pull upstream template updates into a project generated from this starter, use [cargo-generate-update](https://github.com/ogghead/cargo-generate-update) — it tracks the template commit in `.cargo-generate.toml` and performs a three-way merge when you run `cargo generate-update update`.

## Dependencies

### Runtime
- `miette` (v7, features: `fancy`) — Pretty diagnostic error reporting
- `thiserror` (v2) — Derive `Error` trait
- `tracing` (v0.1) — Structured logging (replaces println/eprintln)
- `tracing-subscriber` (v0.3, features: `env-filter`) — Log filtering via `RUST_LOG`

### Dev
- `pretty_assertions` (v1) — Colored diff output for `assert_eq!`
- `insta` (v1, features: `yaml`) — Snapshot testing

## Lint Configuration

Lints are configured in `Cargo.toml` under `[workspace.lints]` and inherited by all crates via `[lints] workspace = true`. Key policies:

- **Unsafe code**: `forbid` — zero unsafe code allowed
- **Clippy baseline**: `all`, `pedantic`, `nursery` at warn level
- **Restriction lints at deny level**:
  - Panic prevention: `unwrap_used`, `expect_used`, `panic`, `todo`, `unimplemented`, `indexing_slicing`
  - Debug artifacts: `dbg_macro`, `print_stdout`, `print_stderr`, `use_debug`
  - Shadowing: `shadow_same`, `shadow_unrelated`
  - Type safety: `as_conversions`, `lossy_float_literal`, `arithmetic_side_effects`
  - Many more (see `Cargo.toml` for full list)
- **Allowed relaxations**: `module_name_repetitions`, `must_use_candidate`, `missing_errors_doc`, `missing_panics_doc`, `option_if_let_else`, `tests_outside_test_module`, `shadow_reuse`, `integer_division`, `str_to_string`, `missing_docs_in_private_items`
- **Clippy thresholds** (in `clippy.toml`): cognitive-complexity = 20, type-complexity = 250

## CI Pipeline

CI runs on push to main and pull requests with 4 parallel jobs (all skip in the template repo itself):

1. **Lint** — `cargo fmt --check`, `cargo clippy -- -D warnings`, `cargo machete` (with sccache for faster builds)
2. **MSRV** — Verifies compilation on Rust 1.93
3. **Deny** — `cargo deny check` (license compliance, security advisories; see `deny.toml` for allowed licenses)
4. **Test + Coverage** — `cargo test --doc` (doc tests) + `cargo llvm-cov nextest --fail-under-lines 90` (unit/integration tests with 90% coverage threshold, `main.rs` excluded)

Concurrency groups cancel stale PR builds automatically to save CI minutes.

## Error Handling

- Use `miette` for all error handling: `#[derive(Diagnostic, Error)]` for library error types, `miette::Result` for binary entry points
- Attach `#[diagnostic(code(app::error_kind), help("..."))]` to give users actionable hints
- Add `#[source_code]` + `#[label("...")]` fields when errors relate to source text
- Always use `?` operator for propagation; `.into_diagnostic()` adapts foreign errors into `miette::Report`
- NEVER use `.unwrap()`, `.expect()`, or `[]` indexing — these are denied by lint
- Use `.ok_or_else(|| miette!("..."))` to convert `Option` to `miette::Result`
- For output, use the `tracing` crate — `println!`/`eprintln!` are forbidden
- Define `Diagnostic` enums per module; re-export from lib.rs

## Testing

- Unit tests: `#[cfg(test)] mod tests { use super::*; }` at bottom of each file
- Integration tests: `tests/` directory at project root
- Name tests descriptively: `test_parse_returns_error_on_empty_input`
- Use `assert_eq!` with context: `assert_eq!(result, expected, "failed for input: {input}")`
- Use `pretty_assertions` for complex comparisons, `insta` for snapshot testing
- Test error cases, not just happy paths

## Gotchas

- `cargo clippy` and `cargo check` share the build cache; running one after the other is fast
- `cargo test` compiles separately from `cargo build` (different cfg); first test run after build changes is slow
- Coverage (`cargo llvm-cov`) re-compiles with instrumentation; first run is slower than plain `cargo test`
- Restriction lints use `deny` not `forbid` because some derive macros (e.g. clap) emit `#[allow(clippy::restriction)]` which is incompatible with `forbid`
