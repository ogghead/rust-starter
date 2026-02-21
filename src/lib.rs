//! Library root for {{project-name}}.

pub mod error;

/// Initialize the application and run the main logic.
///
/// Sets up the miette error handler and tracing subscriber,
/// then executes the application.
pub fn run() -> miette::Result<()> {
    miette::set_hook(Box::new(|_| {
        Box::new(miette::MietteHandlerOpts::new().build())
    }))?;

    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| tracing_subscriber::EnvFilter::new("info")),
        )
        .init();

    tracing::info!("{{project-name}} started");

    Ok(())
}
