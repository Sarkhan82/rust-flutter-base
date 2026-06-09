//! L'agrégat `User` et ses value objects.

use uuid::Uuid;

/// Identifiant fort d'un utilisateur. Newtype : pas interchangeable avec un
/// autre `Uuid` du système — le compilateur refuse les mélanges.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct UserId(Uuid);

impl UserId {
    /// Génère un nouvel identifiant aléatoire (v4).
    #[must_use]
    pub fn new() -> Self {
        Self(Uuid::new_v4())
    }

    /// Reconstruit un `UserId` depuis un `Uuid` existant (ex : lecture DB).
    #[must_use]
    pub fn from_uuid(id: Uuid) -> Self {
        Self(id)
    }

    /// Expose l'`Uuid` sous-jacent (ex : binding SQL, sérialisation).
    #[must_use]
    pub fn as_uuid(&self) -> Uuid {
        self.0
    }
}

impl Default for UserId {
    fn default() -> Self {
        Self::new()
    }
}

impl std::fmt::Display for UserId {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        self.0.fmt(f)
    }
}

/// Adresse email validée. « Parse, don't validate » : une valeur de ce type
/// *prouve* qu'elle a passé la validation — aucune fonction en aval ne
/// revérifie.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Email(String);

impl Email {
    /// Valide et construit un `Email`. Validation volontairement simple pour
    /// un template — adapte-la à ton besoin métier réel.
    ///
    /// # Errors
    /// Renvoie [`EmailError::Invalid`] si l'entrée n'a pas la forme attendue.
    pub fn parse(raw: impl Into<String>) -> Result<Self, EmailError> {
        let raw = raw.into();
        let valid = raw.len() <= 254
            && raw.split_once('@').is_some_and(|(local, domain)| {
                !local.is_empty() && domain.contains('.') && !domain.starts_with('.')
            });
        if valid {
            Ok(Self(raw))
        } else {
            Err(EmailError::Invalid)
        }
    }

    #[must_use]
    pub fn as_str(&self) -> &str {
        &self.0
    }
}

impl std::fmt::Display for Email {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(&self.0)
    }
}

/// Erreur de validation d'un [`Email`].
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
#[non_exhaustive]
pub enum EmailError {
    #[error("adresse email invalide")]
    Invalid,
}

/// L'agrégat utilisateur.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct User {
    pub id: UserId,
    pub email: Email,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_accepts_valid_email() {
        assert!(Email::parse("alice@example.com").is_ok());
    }

    #[test]
    fn parse_rejects_without_at() {
        assert_eq!(Email::parse("nope"), Err(EmailError::Invalid));
    }

    #[test]
    fn parse_rejects_domain_without_dot() {
        assert_eq!(Email::parse("a@localhost"), Err(EmailError::Invalid));
    }

    #[test]
    fn user_ids_are_unique() {
        assert_ne!(UserId::new(), UserId::new());
    }
}
