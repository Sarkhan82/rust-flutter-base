//! Domaine métier PUR : entités, value objects, ports (traits), use cases.
//!
//! Cette crate ne dépend d'aucune infrastructure (ni DB, ni HTTP, ni runtime
//! async concret). Elle définit *ce dont* le métier a besoin via des traits
//! (`ports`) ; les implémentations vivent dans `infra`.

pub mod model;
pub mod ports;
pub mod service;

// Re-exports de confort pour les consommateurs (app, infra).
pub use model::{Email, EmailError, Greeting, User, UserId};
pub use ports::{RepoError, UserRepository};
