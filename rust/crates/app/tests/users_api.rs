//! Tests d'intégration de l'API HTTP, via `tower::oneshot` (pas de port réseau).

use std::sync::Arc;

use app::{AppState, router};
use axum::body::Body;
use axum::http::{Request, StatusCode};
use http_body_util::BodyExt;
use infra::InMemoryUserRepository;
use tower::ServiceExt;

#[expect(
    clippy::unwrap_used,
    reason = "helper de test : la config par défaut est infaillible"
)]
fn test_app() -> axum::Router {
    let state = AppState::new(Arc::new(InMemoryUserRepository::new()));
    router(state).unwrap()
}

#[tokio::test]
async fn health_returns_ok() {
    let resp = test_app()
        .oneshot(
            Request::builder()
                .uri("/health")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(resp.status(), StatusCode::OK);
}

#[tokio::test]
async fn create_then_list_user() {
    let app = test_app();

    // POST /api/v1/users
    let create = app
        .clone()
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/api/v1/users")
                .header("content-type", "application/json")
                .body(Body::from(r#"{"email":"alice@example.com"}"#))
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(create.status(), StatusCode::CREATED);

    // GET /api/v1/users
    let list = app
        .oneshot(
            Request::builder()
                .uri("/api/v1/users")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(list.status(), StatusCode::OK);

    let bytes = list.into_body().collect().await.unwrap().to_bytes();
    let body = String::from_utf8(bytes.to_vec()).unwrap();
    assert!(body.contains("alice@example.com"));
}

#[tokio::test]
async fn create_rejects_invalid_email() {
    let resp = test_app()
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/api/v1/users")
                .header("content-type", "application/json")
                .body(Body::from(r#"{"email":"not-an-email"}"#))
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(resp.status(), StatusCode::UNPROCESSABLE_ENTITY);
}

#[tokio::test]
async fn get_user_by_id_roundtrip() {
    let app = test_app();

    // Crée un utilisateur et récupère son id renvoyé.
    let create = app
        .clone()
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/api/v1/users")
                .header("content-type", "application/json")
                .body(Body::from(r#"{"email":"carol@example.com"}"#))
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(create.status(), StatusCode::CREATED);

    let bytes = create.into_body().collect().await.unwrap().to_bytes();
    let created: serde_json::Value = serde_json::from_slice(&bytes).unwrap();
    let id = created["id"].as_str().unwrap();

    // GET /api/v1/users/{id} → 200 + même email.
    let got = app
        .oneshot(
            Request::builder()
                .uri(format!("/api/v1/users/{id}"))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(got.status(), StatusCode::OK);

    let bytes = got.into_body().collect().await.unwrap().to_bytes();
    let body = String::from_utf8(bytes.to_vec()).unwrap();
    assert!(body.contains("carol@example.com"));
}

#[tokio::test]
async fn get_unknown_user_returns_404() {
    let resp = test_app()
        .oneshot(
            Request::builder()
                .uri("/api/v1/users/00000000-0000-0000-0000-000000000000")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(resp.status(), StatusCode::NOT_FOUND);
}
