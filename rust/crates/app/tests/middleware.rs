//! Tests d'intégration de la stack de middlewares de prod (request-id, CORS,
//! body-limit), via `tower::oneshot`.

use std::sync::Arc;

use app::{AppState, RouterConfig, router, router_with};
use axum::body::Body;
use axum::http::{Request, StatusCode, header};
use infra::InMemoryUserRepository;
use tower::ServiceExt;

fn state() -> AppState {
    AppState::new(Arc::new(InMemoryUserRepository::new()))
}

#[tokio::test]
async fn responses_carry_a_request_id() {
    let resp = router(state())
        .oneshot(
            Request::builder()
                .uri("/health")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(resp.status(), StatusCode::OK);
    assert!(
        resp.headers().contains_key("x-request-id"),
        "la réponse doit propager un x-request-id (corrélation des traces)"
    );
}

#[tokio::test]
async fn cors_is_permissive_by_default() {
    // Config par défaut (allowed_origins vide) ⇒ CORS permissif.
    let resp = router(state())
        .oneshot(
            Request::builder()
                .uri("/health")
                .header(header::ORIGIN, "https://app.exemple.com")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(
        resp.headers()
            .get(header::ACCESS_CONTROL_ALLOW_ORIGIN)
            .map(|v| v.to_str().unwrap_or_default()),
        Some("*"),
        "en mode permissif, toute origine est autorisée"
    );
}

#[tokio::test]
async fn body_over_limit_is_rejected() {
    let cfg = RouterConfig {
        max_body_bytes: 8,
        ..RouterConfig::default()
    };
    let oversized = "x".repeat(1024);

    let resp = router_with(state(), &cfg)
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/api/v1/users")
                .header(header::CONTENT_TYPE, "application/json")
                .header(header::CONTENT_LENGTH, oversized.len())
                .body(Body::from(oversized))
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(
        resp.status(),
        StatusCode::PAYLOAD_TOO_LARGE,
        "un corps au-delà de la limite doit être rejeté en 413"
    );
}
