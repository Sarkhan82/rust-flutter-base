//! Couche application : transport HTTP (axum), wiring, télémétrie.
//!
//! Exposée en bibliothèque pour que les tests d'intégration (et un éventuel
//! second binaire) puissent construire le routeur sans démarrer un serveur.

pub mod http;
pub mod state;
pub mod telemetry;

use axum::Router;
use axum::routing::get;
use tower_http::trace::TraceLayer;

pub use state::AppState;

/// Construit le routeur HTTP complet à partir de l'état applicatif.
///
/// Séparé de `serve` pour être testable via `tower::ServiceExt::oneshot`.
pub fn router(state: AppState) -> Router {
    Router::new()
        .route("/health", get(http::health::health))
        .nest(
            "/api/v1",
            http::users::routes().merge(http::greeting::routes()),
        )
        .layer(TraceLayer::new_for_http())
        .with_state(state)
}
