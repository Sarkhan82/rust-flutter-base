//! Infrastructure : adapters concrets des ports du domaine + configuration.
//!
//! Le template fournit un adapter **in-memory** (zéro dépendance externe →
//! `cargo run` fonctionne immédiatement). Pour brancher Postgres, ajoute un
//! module `postgres` implémentant `domain::UserRepository` (voir
//! docs/RUST_ARCHITECTURE.md §2.4) et sélectionne-le dans le composition root.

pub mod config;
pub mod memory;

pub use config::Config;
pub use memory::InMemoryUserRepository;
