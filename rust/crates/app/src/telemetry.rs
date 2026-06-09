//! Initialisation de la télémétrie (`tracing`).

use tracing_subscriber::EnvFilter;
use tracing_subscriber::layer::SubscriberExt;
use tracing_subscriber::util::SubscriberInitExt;

/// Initialise le subscriber `tracing` global.
///
/// Le filtre vient de `RUST_LOG` si présent, sinon de `level` (config).
/// Format texte lisible en dev ; bascule en `.json()` pour la prod (voir
/// docs/RUST_ARCHITECTURE.md §6.2).
///
/// # Panics
/// Panique si un subscriber global est déjà installé (appel unique attendu,
/// au tout début de `main`).
pub fn init(level: &str) {
    let filter = EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new(level));

    tracing_subscriber::registry()
        .with(filter)
        .with(tracing_subscriber::fmt::layer())
        .init();
}
