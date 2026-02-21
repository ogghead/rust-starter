//! Integration tests for {{project-name}}.

#[test]
fn it_works() {
    assert_eq!(2 + 2, 4, "basic arithmetic should work");
}

#[test]
fn test_run_succeeds() {
    let result = {{crate_name}}::run();
    assert!(result.is_ok(), "run() should complete successfully");
}
