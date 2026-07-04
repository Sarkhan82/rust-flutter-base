//! Endpoint de santé : `GET /health`.

use axum::Json;
use serde::Serialize;

/// Corps de réponse de `GET /health`.
#[derive(Debug, Serialize)]
pub struct HealthResponse {
    /// Toujours `"ok"` tant que le process répond.
    pub status: &'static str,
}

/// Sonde de liveness/readiness — toujours `200 OK` tant que le process tourne.
#[allow(clippy::unused_async)] // signature handler axum : doit être async
pub async fn health() -> Json<HealthResponse> {
    Json(HealthResponse { status: "ok" })
}
