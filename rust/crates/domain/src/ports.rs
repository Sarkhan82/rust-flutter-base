//! Ports : les interfaces (traits) dont le domaine a besoin.
//!
//! Les implémentations concrètes (adapters) vivent dans la crate `infra`.

pub mod user_repository;

pub use user_repository::{RepoError, UserRepository};
