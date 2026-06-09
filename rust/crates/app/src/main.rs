//! Composition root : assemble la config, la télémétrie, les adapters
//! d'infrastructure et le transport HTTP. C'est le SEUL endroit où le concret
//! (in-memory, Postgres, …) rencontre l'abstrait (les ports du domaine).

use std::sync::Arc;
use std::time::Duration;

use anyhow::Context;
use app::{AppState, RouterConfig};
use infra::{Config, InMemoryUserRepository};

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let cfg = Config::load().context("chargement de la configuration")?;
    app::telemetry::init(&cfg.log.level);

    // Choix de l'adapter ici. Pour passer à Postgres : remplace cette ligne par
    // un `PgUserRepository` (cf. docs/RUST_ARCHITECTURE.md §2.4).
    let users = Arc::new(InMemoryUserRepository::new());
    let state = AppState::new(users);

    let router_cfg = RouterConfig {
        allowed_origins: cfg.http.allowed_origins.clone(),
        request_timeout: Duration::from_secs(cfg.http.request_timeout_secs),
        max_body_bytes: cfg.http.max_body_bytes,
    };

    let addr = cfg.http_addr();
    let listener = tokio::net::TcpListener::bind(&addr)
        .await
        .with_context(|| format!("écoute sur {addr}"))?;

    tracing::info!(%addr, "serveur démarré");
    axum::serve(
        listener,
        app::router_with(state, &router_cfg).into_make_service(),
    )
    .with_graceful_shutdown(shutdown_signal())
    .await
    .context("erreur du serveur HTTP")?;

    Ok(())
}

/// Attend un signal d'arrêt (Ctrl-C ou `SIGTERM`) pour déclencher le drainage
/// des requêtes en vol. Indispensable en conteneur/k8s où l'orchestrateur
/// envoie `SIGTERM` avant de tuer le process.
async fn shutdown_signal() {
    let ctrl_c = async {
        if let Err(e) = tokio::signal::ctrl_c().await {
            tracing::error!(error = %e, "installation du handler Ctrl-C");
        }
    };

    #[cfg(unix)]
    let terminate = async {
        match tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate()) {
            Ok(mut sig) => {
                sig.recv().await;
            }
            Err(e) => tracing::error!(error = %e, "installation du handler SIGTERM"),
        }
    };

    #[cfg(not(unix))]
    let terminate = std::future::pending::<()>();

    tokio::select! {
        () = ctrl_c => {},
        () = terminate => {},
    }

    tracing::info!("signal d'arrêt reçu — drainage des requêtes en vol");
}
