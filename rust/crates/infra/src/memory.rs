//! Adapter in-memory du port `UserRepository`. Idéal pour les tests, les démos
//! et le démarrage sans infrastructure.

use std::collections::HashMap;
use std::sync::RwLock;

use async_trait::async_trait;
use domain::model::{User, UserId};
use domain::ports::{RepoError, UserRepository};

/// Stockage en mémoire, thread-safe. Les locks sont pris et relâchés de façon
/// synchrone, jamais tenus à travers un `.await`.
#[derive(Debug, Default)]
pub struct InMemoryUserRepository {
    inner: RwLock<HashMap<UserId, User>>,
}

impl InMemoryUserRepository {
    /// Crée un dépôt vide.
    #[must_use]
    pub fn new() -> Self {
        Self::default()
    }
}

#[async_trait]
impl UserRepository for InMemoryUserRepository {
    async fn list(&self) -> Result<Vec<User>, RepoError> {
        let guard = self
            .inner
            .read()
            .map_err(|_| RepoError::Storage("lock empoisonné".into()))?;
        Ok(guard.values().cloned().collect())
    }

    async fn find(&self, id: UserId) -> Result<Option<User>, RepoError> {
        let guard = self
            .inner
            .read()
            .map_err(|_| RepoError::Storage("lock empoisonné".into()))?;
        Ok(guard.get(&id).cloned())
    }

    async fn save(&self, user: &User) -> Result<(), RepoError> {
        let mut guard = self
            .inner
            .write()
            .map_err(|_| RepoError::Storage("lock empoisonné".into()))?;
        guard.insert(user.id, user.clone());
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use domain::model::Email;

    use super::*;

    #[tokio::test]
    async fn save_then_find_roundtrip() {
        let repo = InMemoryUserRepository::new();
        let user = User {
            id: UserId::new(),
            email: Email::parse("bob@example.com").unwrap(),
        };

        repo.save(&user).await.unwrap();

        assert_eq!(repo.find(user.id).await.unwrap(), Some(user.clone()));
        assert_eq!(repo.list().await.unwrap(), vec![user]);
    }
}
