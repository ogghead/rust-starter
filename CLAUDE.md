# {{project-name}}

Rust application (edition 2024, MSRV 1.93, stable channel).

## Commands

| Command | Purpose |
|---------|---------|
| `cargo check` | Fast type-checking (use first, before build) |
| `cargo build` | Compile debug binary |
| `cargo build --release` | Compile optimized binary |
| `cargo run` | Build and run |
| `cargo test` | Run all tests |
| `cargo nextest run` | Run tests with better output (preferred) |
| `cargo test -- --nocapture` | Run tests showing stdout |
| `cargo test TEST_NAME` | Run a specific test |
| `cargo clippy -- -D warnings` | Lint (warnings = errors) |
| `cargo fmt` | Format code |
| `cargo fmt -- --check` | Check formatting without modifying |
| `cargo doc --open` | Build and open docs |
| `cargo deny check` | Audit dependencies (licenses, advisories, bans) |
| `cargo machete` | Detect unused dependencies |
| `cargo llvm-cov nextest` | Run tests with coverage (text summary) |
| `cargo llvm-cov nextest --html --open` | Coverage report in browser |
| `cargo llvm-cov nextest --lcov --output-path lcov.info` | Generate LCOV for editors |
| `cargo llvm-cov nextest --fail-under-lines 90` | Enforce coverage threshold (matches CI) |
| `cargo llvm-cov clean` | Remove coverage artifacts |

## Workflow

Before committing, always run: `cargo fmt && cargo clippy -- -D warnings && cargo test`

A pre-commit hook automates this — install it with `./scripts/install-hooks.sh`. The hook runs format check, clippy, tests, and optionally `cargo deny check` (if installed).

## Coverage

Install: `cargo install cargo-llvm-cov` (the `llvm-tools` component is already in `rust-toolchain.toml`).

Quick check:
```
cargo llvm-cov nextest
```

HTML report in browser:
```
cargo llvm-cov nextest --html --open
```

Enforce the coverage threshold locally (matches CI):
```
cargo llvm-cov nextest --fail-under-lines 90
```

The threshold is 90% line coverage, enforced in CI.

## Architecture

```
src/
  main.rs          # Thin shim — calls lib::run()
  lib.rs           # Library root — run() entry point and module declarations
  error.rs         # Application error types (miette Diagnostic)
tests/
  integration_test.rs  # Integration tests for run()
scripts/
  install-hooks.sh     # Installs git pre-commit hook
  pre-commit           # Pre-commit hook (fmt, clippy, test, deny)
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

`main.rs` is a one-line shim that calls `{{crate_name}}::run()`. All initialization and application
logic lives in the library crate so it can be tested and covered.

Use file-per-module (mod.rs is legacy). Edition 2024 supports `mod foo;` resolving to `foo.rs` or `foo/mod.rs`, but prefer `foo.rs` for flat modules and `foo/` directory with named files for nested modules.

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

Lints are configured in `Cargo.toml` under `[lints]`. Key policies:

- **Unsafe code**: `forbid` — zero unsafe code allowed
- **Clippy baseline**: `all`, `pedantic`, `nursery` at warn level
- **Restriction lints at deny level**:
  - Panic prevention: `unwrap_used`, `expect_used`, `panic`, `todo`, `unimplemented`, `indexing_slicing`
  - Debug artifacts: `dbg_macro`, `print_stdout`, `print_stderr`, `use_debug`
  - Shadowing: `shadow_reuse`, `shadow_same`, `shadow_unrelated`
  - Type safety: `as_conversions`, `lossy_float_literal`, `arithmetic_side_effects`
  - Documentation: `missing_docs_in_private_items`
  - Many more (see `Cargo.toml` for full list)
- **Allowed relaxations**: `module_name_repetitions`, `must_use_candidate`, `missing_errors_doc`, `missing_panics_doc`, `option_if_let_else`, `tests_outside_test_module`
- **Clippy thresholds** (in `clippy.toml`): cognitive-complexity = 20, type-complexity = 250

## CI Pipeline

CI runs on push to main and pull requests with 5 parallel jobs:

1. **Lint** — `cargo fmt --check`, `cargo clippy -- -D warnings`, `cargo machete`
2. **Test** — `cargo test --doc` (doc tests) + `cargo nextest run` (unit/integration)
3. **MSRV** — Verifies compilation on Rust 1.93
4. **Deny** — `cargo deny check` for license compliance and security advisories
5. **Coverage** — `cargo llvm-cov nextest --fail-under-lines 90` (enforces 90% threshold)

## Rust Conventions

### Error Handling
- Use `miette` for all error handling: `#[derive(Diagnostic, Error)]` for library error types, `miette::Result` for application/binary entry points
- Attach `#[diagnostic(code(app::error_kind), help("..."))]` to give users actionable hints
- Add `#[source_code]` + `#[label("...")]` fields when errors relate to source text (parsers, configs)
- Always use `?` operator for propagation; `.into_diagnostic()` adapts foreign errors into `miette::Report`
- NEVER use `.unwrap()`, `.expect()`, or `.get().unwrap()` — these are denied by lint
- Use `.ok_or_else(|| miette!("..."))` to convert `Option` to `miette::Result`
- Use `.get()` instead of `[]` indexing, or prove bounds with `assert!` + comment
- For output, use the `tracing` crate — `println!`/`eprintln!` are forbidden
- Define `Diagnostic` enums per module; re-export from lib.rs
- Install the `miette` pretty handler in `main`: `miette::set_hook(Box::new(|_| Box::new(miette::MietteHandlerOpts::new().build())))?`

### Types and APIs
- Derive `Debug` on all public types; derive `Clone, PartialEq, Eq` when sensible
- Use `#[must_use]` on functions whose return value should not be ignored
- Accept `&str` not `&String`, `&[T]` not `&Vec<T>`, `impl AsRef<Path>` not `&PathBuf`
- Use `impl Into<T>` for flexible constructors
- Prefer `Default::default()` over `new()` with no parameters when semantically appropriate

### Patterns
- Prefer iterators and combinators over index-based loops
- Use `if let` / `let else` for single-pattern matching instead of full `match`
- Builder pattern for complex construction (3+ optional fields)
- Newtype pattern for domain types that wrap primitives
- Prefer `From`/`Into` implementations over ad-hoc conversion methods

### Testing
- Unit tests: `#[cfg(test)] mod tests { use super::*; }` at bottom of each file
- Integration tests: `tests/` directory at project root
- Name tests descriptively: `test_parse_returns_error_on_empty_input`
- Use `assert_eq!` / `assert_ne!` with context: `assert_eq!(result, expected, "failed for input: {input}")`
- Use `pretty_assertions` for better diff output on complex comparisons
- Use `insta` for snapshot testing when output is large or evolving
- Test error cases, not just happy paths

### Edition 2024 Notes
- `gen` is a reserved keyword (cannot use as identifier)
- `unsafe_op_in_unsafe_fn` is warn-by-default
- Lifetime capture rules changed for `impl Trait` in return position
- `if let` temporaries have tighter scoping

## Release Profile

The release build is optimized for size and speed:
- `lto = "thin"` — Link-time optimization
- `codegen-units = 1` — Maximum optimization
- `strip = true` — Remove debug symbols
- `panic = "abort"` — Smaller binary (no unwinding)

## Template System

This repo doubles as a `cargo-generate` template. Files contain `{{project-name}}` and `{{crate_name}}` placeholders. Template config is in `cargo-generate.toml`. The `template-test.yml` CI workflow validates that generated projects compile and pass all checks.

## Using MCP Tools

### rust-analyzer-mcp
- Use `rust_analyzer_diagnostics` after editing to catch errors before running cargo
- Use `rust_analyzer_hover` to check types and documentation inline
- Use `rust_analyzer_definition` / `rust_analyzer_references` to navigate code
- Set workspace first: `rust_analyzer_set_workspace` to project root

### rust-docs-mcp
- Use `search_items_preview` first (lightweight), then `get_item_details` for specifics
- Use `structure` to understand crate organization before diving in
- Cache local project: `cache_crate_from_local` for self-documentation
- Cache dependencies: `cache_crate_from_cratesio` for dependency docs

### rust-mcp-server
- Run cargo commands autonomously: `cargo-check`, `cargo-build`, `cargo-test`, `cargo-clippy`, `cargo-fmt`
- Manage dependencies: `cargo-add`, `cargo-remove`, `cargo-update`, `cargo-search`
- Audit: `cargo-deny` (licenses/advisories), `cargo-machete` (unused deps)
- Explain compiler errors: `rustc-explain <error_code>` (e.g. E0502)
- Use instead of asking the user to run cargo commands manually

### vestige (cross-session memory)
- Store architectural decisions with `smart_ingest` when making significant choices
- Store error patterns and solutions that took effort to discover
- Search before starting work on a returning topic with `search`

### code-indexer
- Set project path at session start
- Use `search_code_advanced` for regex search across codebase
- Use `get_file_summary` for quick orientation on unfamiliar files

## Session Start

At the beginning of each session:
1. Set rust-analyzer workspace: `rust_analyzer_set_workspace` to the project root
2. Set code-indexer project path to the project root
3. Check vestige for project context: `search("{{project-name}}")`

## Dependency Audit (deny.toml)

Allowed licenses: MIT, Apache-2.0, BSD-2-Clause, BSD-3-Clause, ISC, Unicode-3.0, Unicode-DFS-2016. Unknown registries and git sources are denied. Wildcard dependencies are denied. Multiple versions produce warnings.

## Gotchas

- `cargo clippy` and `cargo check` share the build cache; running one after the other is fast
- `cargo test` compiles separately from `cargo build` (different cfg); first test run after build changes is slow
- Edition 2024 changed `unsafe_op_in_unsafe_fn` to warn-by-default; use explicit `unsafe {}` blocks inside unsafe fns
- Clippy pedantic lint `module_name_repetitions` fires when struct name contains module name (e.g., `foo::FooBar`); this is allowed by our lint config
- Coverage (`cargo llvm-cov`) re-compiles with instrumentation; first run is slower than plain `cargo test`
- Restriction lints use `deny` not `forbid` because some derive macros (e.g. clap) emit `#[allow(clippy::restriction)]` which is incompatible with `forbid`
- This repo is also a `cargo-generate` template — source files contain `{{placeholder}}` syntax that gets replaced during generation
