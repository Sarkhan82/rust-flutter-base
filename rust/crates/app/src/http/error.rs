//! Traduction des erreurs métier en réponses HTTP. Frontière de l'app : c'est
//! ici qu'on décide du status code et du corps JSON exposés au client.

use axum::Json;
use axum::http::StatusCode;
use axum::response::{IntoResponse, Response};
use domain::model::EmailError;
use domain::ports::RepoError;
use domain::service::RegisterError;
use serde::Serialize;

/// Erreur HTTP de l'API.
#[derive(Debug)]
pub enum ApiError {
    /// Entrée invalide → 422.
    Validation(String),
    /// Ressource absente → 404.
    NotFound,
    /// Erreur interne non exposée au client → 500.
    Internal,
}

#[derive(Serialize)]
struct ErrorBody {
    error: String,
    message: String,
}

impl IntoResponse for ApiError {
    fn into_response(self) -> Response {
        let (status, error, message) = match self {
            ApiError::Validation(msg) => (StatusCode::UNPROCESSABLE_ENTITY, "validation", msg),
            ApiError::NotFound => (
                StatusCode::NOT_FOUND,
                "not_found",
                "ressource introuvable".to_owned(),
            ),
            ApiError::Internal => (
                StatusCode::INTERNAL_SERVER_ERROR,
                "internal",
                "erreur interne".to_owned(),
            ),
        };
        (
            status,
            Json(ErrorBody {
                error: error.to_owned(),
                message,
            }),
        )
            .into_response()
    }
}

impl From<EmailError> for ApiError {
    fn from(e: EmailError) -> Self {
        ApiError::Validation(e.to_string())
    }
}

impl From<RepoError> for ApiError {
    fn from(e: RepoError) -> Self {
        // On logge la cause réelle mais on ne la fuit pas au client.
        tracing::error!(error = %e, "erreur de stockage");
        ApiError::Internal
    }
}

impl From<RegisterError> for ApiError {
    fn from(e: RegisterError) -> Self {
        match e {
            RegisterError::Repo(r) => r.into(),
            // `RegisterError` est #[non_exhaustive] (cf. §3.4) : bras requis
            // pour les variantes futures. Par défaut, erreur interne.
            _ => ApiError::Internal,
        }
    }
}
