//! Couche application : transport HTTP (axum), wiring, télémétrie.
//!
//! Exposée en bibliothèque pour que les tests d'intégration (et un éventuel
//! second binaire) puissent construire le routeur sans démarrer un serveur.

pub mod http;
pub mod state;
pub mod telemetry;

use std::time::Duration;

use axum::Router;
use axum::http::{HeaderValue, StatusCode};
use axum::routing::get;
use tower_http::cors::{AllowOrigin, Any, CorsLayer};
use tower_http::limit::RequestBodyLimitLayer;
use tower_http::request_id::{MakeRequestUuid, PropagateRequestIdLayer, SetRequestIdLayer};
use tower_http::timeout::TimeoutLayer;
use tower_http::trace::TraceLayer;

pub use state::AppState;

/// Réglages des middlewares HTTP de production. Construits depuis la config au
/// démarrage ; `Default` fournit des valeurs dev raisonnables pour les tests.
#[derive(Debug, Clone)]
pub struct RouterConfig {
    /// Origines CORS autorisées. Vide ⇒ permissif (dev).
    pub allowed_origins: Vec<String>,
    /// Délai max d'une requête avant `408`.
    pub request_timeout: Duration,
    /// Taille max du corps de requête (octets).
    pub max_body_bytes: usize,
}

impl Default for RouterConfig {
    fn default() -> Self {
        Self {
            allowed_origins: Vec::new(),
            request_timeout: Duration::from_secs(30),
            max_body_bytes: 2 * 1024 * 1024, // 2 Mio
        }
    }
}

/// Erreur de construction du routeur : configuration invalide.
///
/// Volontairement **fatale** : une config invalide empêche le démarrage
/// (fail-fast), plutôt que de dégrader silencieusement la sécurité au runtime.
#[derive(Debug, thiserror::Error)]
#[non_exhaustive]
pub enum RouterError {
    /// Une origine CORS de la config n'est pas une valeur de header valide.
    #[error("origine CORS invalide dans la config : {origin:?}")]
    InvalidCorsOrigin {
        /// La valeur rejetée, telle que fournie dans la config.
        origin: String,
    },
}

/// Construit le routeur HTTP avec les middlewares de prod par défaut.
///
/// Raccourci de [`router_with`] utilisé par les tests d'intégration.
///
/// # Errors
/// Voir [`router_with`] — infaillible avec la config par défaut (CORS permissif).
pub fn router(state: AppState) -> Result<Router, RouterError> {
    router_with(state, &RouterConfig::default())
}

/// Construit le routeur HTTP complet : routes + stack de middlewares de prod.
///
/// Ordre des couches (axum applique la **dernière** `.layer` en plus externe) :
/// request-id (outermost) → trace → CORS → timeout → body-limit (innermost).
/// Ainsi l'id de requête existe pour toute la chaîne, le préflight/CORS est
/// traité avant de consommer le corps, et le timeout borne tout handler.
///
/// # Errors
/// [`RouterError::InvalidCorsOrigin`] si une origine configurée ne parse pas :
/// on refuse de démarrer plutôt que de servir avec un CORS différent de celui
/// demandé (fail-fast sur la config).
pub fn router_with(state: AppState, cfg: &RouterConfig) -> Result<Router, RouterError> {
    Ok(Router::new()
        .route("/health", get(http::health::health))
        .nest(
            "/api/v1",
            http::users::routes().merge(http::greeting::routes()),
        )
        // innermost → outermost (lire de bas en haut pour l'ordre d'exécution)
        .layer(RequestBodyLimitLayer::new(cfg.max_body_bytes))
        .layer(TimeoutLayer::with_status_code(
            StatusCode::REQUEST_TIMEOUT,
            cfg.request_timeout,
        ))
        .layer(cors_layer(&cfg.allowed_origins)?)
        .layer(TraceLayer::new_for_http())
        .layer(PropagateRequestIdLayer::x_request_id())
        .layer(SetRequestIdLayer::x_request_id(MakeRequestUuid))
        .with_state(state))
}

/// Construit la couche CORS. Liste vide ⇒ permissif (dev, avec avertissement) ;
/// sinon restreint aux origines explicitement autorisées.
///
/// Une origine invalide est une **erreur** (pas un skip silencieux) : la config
/// effective doit toujours être exactement la config demandée.
fn cors_layer(allowed_origins: &[String]) -> Result<CorsLayer, RouterError> {
    if allowed_origins.is_empty() {
        tracing::warn!(
            "CORS permissif (toute origine) — OK en dev, À RESTREINDRE en prod \
             via APP_HTTP__ALLOWED_ORIGINS"
        );
        return Ok(CorsLayer::permissive());
    }

    let origins: Vec<HeaderValue> = allowed_origins
        .iter()
        .map(|o| {
            o.parse::<HeaderValue>()
                .map_err(|_| RouterError::InvalidCorsOrigin { origin: o.clone() })
        })
        .collect::<Result<_, _>>()?;

    Ok(CorsLayer::new()
        .allow_origin(AllowOrigin::list(origins))
        .allow_methods(Any)
        .allow_headers(Any))
}
