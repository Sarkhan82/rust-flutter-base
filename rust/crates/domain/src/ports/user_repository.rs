//! Port de persistance des utilisateurs.

use std::sync::Arc;

use async_trait::async_trait;

use crate::model::{User, UserId};

/// Port : contrat de stockage des [`User`].
///
/// On utilise `#[async_trait]` pour rendre le trait **dyn-compatible** : l'app
/// stocke un `Arc<dyn UserRepository>` et choisit l'adapter (in-memory,
/// Postgres, …) au runtime selon la config. C'est le cas où le dispatch
/// dynamique est justifié (cf. docs/RUST_ARCHITECTURE.md §5.4). Le coût (un
/// future boxé) est négligeable face à une I/O réseau/DB.
#[async_trait]
pub trait UserRepository: Send + Sync {
    /// Liste tous les utilisateurs.
    async fn list(&self) -> Result<Vec<User>, RepoError>;

    /// Récupère un utilisateur par son id, `None` si absent.
    async fn find(&self, id: UserId) -> Result<Option<User>, RepoError>;

    /// Persiste (insert ou upsert) un utilisateur.
    async fn save(&self, user: &User) -> Result<(), RepoError>;
}

/// Permet de passer un `Arc<dyn UserRepository>` (ou `Arc<ConcreteRepo>`)
/// partout où un `UserRepository` est attendu, sans wrapper manuel.
#[async_trait]
impl<T: UserRepository + ?Sized> UserRepository for Arc<T> {
    async fn list(&self) -> Result<Vec<User>, RepoError> {
        (**self).list().await
    }
    async fn find(&self, id: UserId) -> Result<Option<User>, RepoError> {
        (**self).find(id).await
    }
    async fn save(&self, user: &User) -> Result<(), RepoError> {
        (**self).save(user).await
    }
}

/// Erreur de la couche de persistance. `#[non_exhaustive]` : on pourra ajouter
/// des variantes (Conflict, Timeout, …) sans casser les callers.
#[derive(Debug, thiserror::Error)]
#[non_exhaustive]
pub enum RepoError {
    /// Échec technique de la couche de stockage (connexion, I/O, lock…).
    #[error("erreur de stockage : {0}")]
    Storage(String),
}
