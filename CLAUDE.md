# {{project-name}}

Rust application (edition 2024, rustc 1.92.0, stable channel).

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
| `cargo deny check` | Audit dependencies |
| `cargo llvm-cov nextest` | Run tests with coverage (text summary) |
| `cargo llvm-cov nextest --html --open` | Coverage report in browser |
| `cargo llvm-cov nextest --lcov --output-path lcov.info` | Generate LCOV for editors |
| `cargo llvm-cov clean` | Remove coverage artifacts |

## Workflow

Before committing, always run: `cargo fmt && cargo clippy -- -D warnings && cargo test`

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
cargo llvm-cov nextest --fail-under-lines 60
```

The baseline is 60% due to untestable code (miette hook closure, binary entry point).
Raise this as the codebase grows and the ratio of testable library code increases.

## Architecture

```
src/
  main.rs     # Thin shim — calls lib::run()
  lib.rs      # Library root — run() entry point and module declarations
  error.rs    # Application error types (miette Diagnostic)
tests/        # Integration tests
```

`main.rs` is a one-line shim that calls `{{crate_name}}::run()`. All initialization and application
logic lives in the library crate so it can be tested and covered.

Use file-per-module (mod.rs is legacy). Edition 2024 supports `mod foo;` resolving to `foo.rs` or `foo/mod.rs`, but prefer `foo.rs` for flat modules and `foo/` directory with named files for nested modules.

## Rust Conventions

### Error Handling
- Use `miette` for all error handling: `#[derive(Diagnostic, Error)]` for library error types, `miette::Result` for application/binary entry points
- Attach `#[diagnostic(code(app::error_kind), help("..."))]` to give users actionable hints
- Add `#[source_code]` + `#[label("...")]` fields when errors relate to source text (parsers, configs)
- Always use `?` operator for propagation; `.into_diagnostic()` adapts foreign errors into `miette::Report`
- NEVER use `.unwrap()`, `.expect()`, or `.get().unwrap()` — these are forbidden by lint
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
- Test error cases, not just happy paths

### Edition 2024 Notes
- `gen` is a reserved keyword (cannot use as identifier)
- `unsafe_op_in_unsafe_fn` is warn-by-default
- Lifetime capture rules changed for `impl Trait` in return position
- `if let` temporaries have tighter scoping

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

## Gotchas

- `cargo clippy` and `cargo check` share the build cache; running one after the other is fast
- `cargo test` compiles separately from `cargo build` (different cfg); first test run after build changes is slow
- Edition 2024 changed `unsafe_op_in_unsafe_fn` to warn-by-default; use explicit `unsafe {}` blocks inside unsafe fns
- Clippy pedantic lint `module_name_repetitions` fires when struct name contains module name (e.g., `foo::FooBar`); this is allowed by our lint config
- Coverage (`cargo llvm-cov`) re-compiles with instrumentation; first run is slower than plain `cargo test`
