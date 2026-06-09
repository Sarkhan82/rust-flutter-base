//! Use case : récupérer un utilisateur par son identifiant.

use crate::model::{User, UserId};
use crate::ports::{RepoError, UserRepository};

/// Récupère un utilisateur par son id. Générique sur le repo → dispatch
/// statique, zéro coût. Renvoie `None` si l'utilisateur n'existe pas (la
/// traduction en 404 est la responsabilité de la couche transport).
pub struct GetUser<R: UserRepository> {
    repo: R,
}

impl<R: UserRepository> GetUser<R> {
    pub fn new(repo: R) -> Self {
        Self { repo }
    }

    /// # Errors
    /// Propage l'erreur de stockage du repo.
    pub async fn execute(&self, id: UserId) -> Result<Option<User>, RepoError> {
        self.repo.find(id).await
    }
}

#[cfg(test)]
mod tests {
    use std::sync::Mutex;

    use async_trait::async_trait;

    use super::*;
    use crate::model::Email;

    #[derive(Default)]
    struct InMemoryRepo {
        users: Mutex<Vec<User>>,
    }

    #[async_trait]
    impl UserRepository for InMemoryRepo {
        async fn list(&self) -> Result<Vec<User>, RepoError> {
            Ok(self.users.lock().unwrap().clone())
        }
        async fn find(&self, id: UserId) -> Result<Option<User>, RepoError> {
            let found = self
                .users
                .lock()
                .unwrap()
                .iter()
                .find(|u| u.id == id)
                .cloned();
            Ok(found)
        }
        async fn save(&self, user: &User) -> Result<(), RepoError> {
            self.users.lock().unwrap().push(user.clone());
            Ok(())
        }
    }

    #[tokio::test]
    async fn get_returns_some_when_present() {
        let repo = InMemoryRepo::default();
        let user = User {
            id: UserId::new(),
            email: Email::parse("alice@example.com").unwrap(),
        };
        repo.save(&user).await.unwrap();

        let svc = GetUser::new(repo);
        assert_eq!(svc.execute(user.id).await.unwrap(), Some(user));
    }

    #[tokio::test]
    async fn get_returns_none_when_absent() {
        let svc = GetUser::new(InMemoryRepo::default());
        assert_eq!(svc.execute(UserId::new()).await.unwrap(), None);
    }
}
