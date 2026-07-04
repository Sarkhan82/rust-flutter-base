//! Use case : enregistrer un nouvel utilisateur.

use crate::model::{Email, User, UserId};
use crate::ports::{RepoError, UserRepository};

/// Crée et persiste un utilisateur. Générique sur le repo → dispatch statique,
/// zéro coût ; testable avec n'importe quelle implémentation du port.
pub struct RegisterUser<R: UserRepository> {
    repo: R,
}

impl<R: UserRepository> RegisterUser<R> {
    /// Construit le use case avec le repo fourni.
    pub fn new(repo: R) -> Self {
        Self { repo }
    }

    /// Enregistre l'utilisateur et renvoie l'entité créée.
    ///
    /// # Errors
    /// Propage une [`RegisterError`] si la persistance échoue.
    pub async fn execute(&self, email: Email) -> Result<User, RegisterError> {
        let user = User {
            id: UserId::new(),
            email,
        };
        self.repo.save(&user).await?;
        Ok(user)
    }
}

/// Erreur du use case d'enregistrement.
#[derive(Debug, thiserror::Error)]
#[non_exhaustive]
pub enum RegisterError {
    /// Échec de la persistance de l'utilisateur.
    #[error(transparent)]
    Repo(#[from] RepoError),
}

#[cfg(test)]
mod tests {
    use std::sync::Mutex;

    use async_trait::async_trait;

    use super::*;
    use crate::model::User;

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
            // lock pris et relâché AVANT tout await (cf. §4.2)
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
    async fn register_persists_user() {
        let svc = RegisterUser::new(InMemoryRepo::default());
        let email = Email::parse("alice@example.com").unwrap();

        let created = svc.execute(email.clone()).await.unwrap();

        assert_eq!(created.email, email);
        assert!(svc.repo.find(created.id).await.unwrap().is_some());
    }
}
