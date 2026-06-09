//! Ressource `greeting` : `GET /api/v1/greeting?name=...`.
//!
//! Feature témoin de bout en bout **Flutter ↔ Rust en HTTP**. Sans port ni état :
//! pure démonstration du câblage transport → domaine. Côté Flutter, la feature
//! `greeting` consomme ce endpoint via un client HTTP.

use axum::Json;
use axum::Router;
use axum::extract::Query;
use axum::routing::get;
use domain::model::Greeting;
use serde::{Deserialize, Serialize};

use crate::state::AppState;

/// Route de la ressource, montée sous `/api/v1` par le routeur racine.
pub fn routes() -> Router<AppState> {
    Router::new().route("/greeting", get(greeting))
}

#[derive(Debug, Deserialize)]
pub struct GreetingParams {
    /// Nom à saluer. Absent ou vide → salutation générique.
    #[serde(default)]
    pub name: String,
}

#[derive(Debug, Serialize)]
pub struct GreetingResponse {
    pub message: String,
}

/// `GET /api/v1/greeting?name=Alice`
#[allow(clippy::unused_async)] // signature handler axum : doit être async
async fn greeting(Query(params): Query<GreetingParams>) -> Json<GreetingResponse> {
    let message = Greeting::for_name(&params.name).into_message();
    Json(GreetingResponse { message })
}
