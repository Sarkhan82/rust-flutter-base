//! Value object `Greeting` : un message de salutation.
//!
//! Logique de domaine **pure** (aucune I/O, aucun port). Sert de feature témoin
//! démontrant le câblage transport → domaine, et illustre qu'un use case sans
//! dépendance externe vit quand même dans le domaine, pas dans la couche HTTP.

/// Message de salutation construit pour un nom donné.
///
/// Newtype plutôt qu'un `String` nu : le type porte la sémantique « ceci est une
/// salutation déjà formée », pas une chaîne quelconque.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Greeting(String);

impl Greeting {
    /// Construit la salutation pour `name`. Un nom vide (ou seulement des
    /// espaces) retombe sur une salutation générique.
    #[must_use]
    pub fn for_name(name: &str) -> Self {
        let who = name.trim();
        let who = if who.is_empty() { "monde" } else { who };
        Self(format!("Bonjour, {who} ! 👋"))
    }

    /// Le message sous forme de `&str`.
    #[must_use]
    pub fn as_str(&self) -> &str {
        &self.0
    }

    /// Consomme la salutation et renvoie le message possédé.
    #[must_use]
    pub fn into_message(self) -> String {
        self.0
    }
}

#[cfg(test)]
mod tests {
    use super::Greeting;

    #[test]
    fn greets_named_person() {
        assert_eq!(Greeting::for_name("Alice").as_str(), "Bonjour, Alice ! 👋");
    }

    #[test]
    fn trims_surrounding_whitespace() {
        assert_eq!(Greeting::for_name("  Bob  ").as_str(), "Bonjour, Bob ! 👋");
    }

    #[test]
    fn empty_name_falls_back_to_generic() {
        assert_eq!(Greeting::for_name("   ").as_str(), "Bonjour, monde ! 👋");
    }
}
