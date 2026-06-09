//! Ressource `users` : `GET /api/v1/users`, `POST /api/v1/users`.

use axum::extract::{Path, State};
use axum::http::StatusCode;
use axum::routing::get;
use axum::{Json, Router};
use domain::model::{Email, User, UserId};
use domain::service::{GetUser, ListUsers, RegisterUser};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use super::error::ApiError;
use crate::state::AppState;

/// Routes de la ressource, montées sous `/api/v1` par le routeur racine.
pub fn routes() -> Router<AppState> {
    Router::new()
        .route("/users", get(list_users).post(create_user))
        .route("/users/{id}", get(get_user))
}

/// Représentation transport d'un utilisateur (jamais le type domaine direct :
/// le DTO découple le contrat d'API du modèle interne).
#[derive(Debug, Serialize)]
pub struct UserDto {
    pub id: Uuid,
    pub email: String,
}

impl From<User> for UserDto {
    fn from(u: User) -> Self {
        Self {
            id: u.id.as_uuid(),
            email: u.email.as_str().to_owned(),
        }
    }
}

#[derive(Debug, Deserialize)]
pub struct CreateUserRequest {
    pub email: String,
}

/// `GET /api/v1/users`
async fn list_users(State(state): State<AppState>) -> Result<Json<Vec<UserDto>>, ApiError> {
    let users = ListUsers::new(state.users.clone()).execute().await?;
    Ok(Json(users.into_iter().map(UserDto::from).collect()))
}

/// `POST /api/v1/users`
async fn create_user(
    State(state): State<AppState>,
    Json(body): Json<CreateUserRequest>,
) -> Result<(StatusCode, Json<UserDto>), ApiError> {
    let email = Email::parse(body.email)?;
    let created = RegisterUser::new(state.users.clone())
        .execute(email)
        .await?;
    Ok((StatusCode::CREATED, Json(UserDto::from(created))))
}

/// `GET /api/v1/users/{id}` — `404 not_found` si l'utilisateur n'existe pas.
async fn get_user(
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
) -> Result<Json<UserDto>, ApiError> {
    let user = GetUser::new(state.users.clone())
        .execute(UserId::from_uuid(id))
        .await?
        .ok_or(ApiError::NotFound)?;
    Ok(Json(UserDto::from(user)))
}
