//! Integration tests for rust-starter.

#[test]
fn test_run_succeeds() {
    let result = rust_starter::run();
    assert!(result.is_ok(), "run() should complete successfully");
}
