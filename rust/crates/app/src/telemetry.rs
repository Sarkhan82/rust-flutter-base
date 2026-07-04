//! Initialisation de la télémétrie (`tracing`).

use infra::config::{LogConfig, LogFormat};
use tracing_subscriber::EnvFilter;
use tracing_subscriber::layer::SubscriberExt;
use tracing_subscriber::util::SubscriberInitExt;

/// Initialise le subscriber `tracing` global.
///
/// Le filtre vient de `RUST_LOG` si présent, sinon de `cfg.level`. Le format
/// vient de `cfg.format` : `text` lisible en dev, `json` structuré pour la
/// prod (ingestion par un collecteur de logs). Surcharge : `APP_LOG__FORMAT=json`.
///
/// # Panics
/// Panique si un subscriber global est déjà installé (appel unique attendu,
/// au tout début de `main`).
pub fn init(cfg: &LogConfig) {
    let filter = EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new(&cfg.level));
    let registry = tracing_subscriber::registry().with(filter);

    match cfg.format {
        LogFormat::Text => registry.with(tracing_subscriber::fmt::layer()).init(),
        LogFormat::Json => registry
            .with(tracing_subscriber::fmt::layer().json())
            .init(),
    }
}
