//! Use case : lister les utilisateurs.

use crate::model::User;
use crate::ports::{RepoError, UserRepository};

/// Renvoie tous les utilisateurs connus.
pub struct ListUsers<R: UserRepository> {
    repo: R,
}

impl<R: UserRepository> ListUsers<R> {
    /// Construit le use case avec le repo fourni.
    pub fn new(repo: R) -> Self {
        Self { repo }
    }

    /// # Errors
    /// Propage l'erreur de stockage du repo.
    pub async fn execute(&self) -> Result<Vec<User>, RepoError> {
        self.repo.list().await
    }
}
