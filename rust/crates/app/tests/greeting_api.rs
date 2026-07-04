//! Tests d'intégration de la ressource `greeting`, via `tower::oneshot`.

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
async fn greeting_with_name() {
    let resp = test_app()
        .oneshot(
            Request::builder()
                .uri("/api/v1/greeting?name=Alice")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(resp.status(), StatusCode::OK);

    let bytes = resp.into_body().collect().await.unwrap().to_bytes();
    let body: serde_json::Value = serde_json::from_slice(&bytes).unwrap();
    assert_eq!(body["message"], "Bonjour, Alice ! 👋");
}

#[tokio::test]
async fn greeting_without_name_falls_back() {
    let resp = test_app()
        .oneshot(
            Request::builder()
                .uri("/api/v1/greeting")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(resp.status(), StatusCode::OK);

    let bytes = resp.into_body().collect().await.unwrap().to_bytes();
    let body: serde_json::Value = serde_json::from_slice(&bytes).unwrap();
    assert_eq!(body["message"], "Bonjour, monde ! 👋");
}
