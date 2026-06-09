//! Modèle du domaine : entités et value objects.

pub mod greeting;
pub mod user;

pub use greeting::Greeting;
pub use user::{Email, EmailError, User, UserId};
