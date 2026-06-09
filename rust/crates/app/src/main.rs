//! Composition root : assemble la config, la télémétrie, les adapters
//! d'infrastructure et le transport HTTP. C'est le SEUL endroit où le concret
//! (in-memory, Postgres, …) rencontre l'abstrait (les ports du domaine).

use std::sync::Arc;

use anyhow::Context;
use app::AppState;
use infra::{Config, InMemoryUserRepository};

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let cfg = Config::load().context("chargement de la configuration")?;
    app::telemetry::init(&cfg.log.level);

    // Choix de l'adapter ici. Pour passer à Postgres : remplace cette ligne par
    // un `PgUserRepository` (cf. docs/RUST_ARCHITECTURE.md §2.4).
    let users = Arc::new(InMemoryUserRepository::new());
    let state = AppState::new(users);

    let addr = cfg.http_addr();
    let listener = tokio::net::TcpListener::bind(&addr)
        .await
        .with_context(|| format!("écoute sur {addr}"))?;

    tracing::info!(%addr, "serveur démarré");
    axum::serve(listener, app::router(state).into_make_service())
        .await
        .context("erreur du serveur HTTP")?;

    Ok(())
}
