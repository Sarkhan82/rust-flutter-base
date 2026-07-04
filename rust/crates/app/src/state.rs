//! État applicatif partagé entre les handlers axum.

use std::sync::Arc;

use domain::ports::UserRepository;

/// État injecté dans chaque handler. `Clone` est bon marché (compteurs `Arc`).
///
/// On stocke un `Arc<dyn UserRepository>` : l'adapter concret (in-memory,
/// Postgres, …) est choisi dans le composition root (`main.rs`) sans que la
/// couche HTTP n'en sache rien.
#[derive(Clone)]
pub struct AppState {
    /// Port de persistance des utilisateurs (adapter choisi dans `main`).
    pub users: Arc<dyn UserRepository>,
}

impl AppState {
    /// Construit l'état applicatif avec le repo fourni.
    #[must_use]
    pub fn new(users: Arc<dyn UserRepository>) -> Self {
        Self { users }
    }
}
