# Backend — règles d'architecture & contribution

> Le guide complet est dans `../docs/RUST_ARCHITECTURE.md`. Ce fichier en est le
> condensé opérationnel : ce qu'il faut respecter pour toute contribution au
> backend Rust.

## Structure (hexagonal — ports & adapters)

```
crates/
├── domain/   # logique PURE. Dépend de RIEN d'infra/runtime.
│   ├── model/     # entités + value objects (newtypes)
│   ├── ports/     # traits = interfaces dont le métier a besoin
│   └── service/   # use cases
├── infra/    # adapters concrets des ports + config. Dépend de `domain`.
└── app/      # transport HTTP (axum) + wiring + télémétrie. Bin.
```

**Sens des dépendances : toujours vers le domaine.** `domain` n'importe jamais
`infra` ni `app`. Toute violation casse le découplage et doit être refusée en revue.

## Nommage

- Modules : convention **fichier nommé** (`foo.rs` + dossier `foo/`). **Pas de `mod.rs`** (lint `clippy::mod_module_files`).
- Types : `PascalCase` ; fonctions/variables : `snake_case` ; constantes : `SCREAMING_SNAKE_CASE`.
- Un **newtype** par primitif porteur de sémantique (`UserId`, `Email`) — jamais un `String`/`Uuid` nu qui traverse les couches.
- Ports nommés par capacité métier (`UserRepository`), pas par techno (`PostgresClient`).
- DTOs HTTP suffixés `Dto`/`Request`/`Response`, dans `app/http/`, jamais exposer un type `domain` directement sur le réseau.

## Règles non négociables

1. Zéro `unwrap`/`expect`/`panic` en code de prod (autorisés en `#[cfg(test)]` via `clippy.toml`).
2. `thiserror` dans `domain`/`infra` ; `anyhow` seulement dans `app` (frontières).
3. Erreurs publiques en `#[non_exhaustive]` + chaîne préservée (`#[source]`/`#[from]`).
4. « Parse, don't validate » : valider à la frontière, propager le type-preuve.
5. Pas de lock (`std::sync::Mutex`) tenu à travers un `.await`.
6. `tracing` pour les logs ; **jamais de PII en clair** (email, token…) dans les spans/logs.
7. Tout nouveau use case = test unitaire ; toute route = test d'intégration dans `app/tests/`.

## Avant de pousser

```bash
cargo fmt --all -- --check
cargo clippy --workspace --all-targets -- -D warnings
cargo test --workspace
cargo deny check          # si cargo-deny installé
```

La CI (`.github/workflows/rust-ci.yml`) rejoue tout ça. Un PR qui ne passe pas est bloqué.

## Étendre vers une vraie DB

L'adapter par défaut est `infra::InMemoryUserRepository`. Pour Postgres :
1. ajoute `sqlx` (feature `postgres`) dans `infra` ;
2. crée `infra/src/postgres/user_repo.rs` implémentant `domain::UserRepository` ;
3. `cargo sqlx prepare` → commite `.sqlx/` (sinon la CI casse, cf. §8.4 du guide) ;
4. dans `app/src/main.rs`, remplace la construction de l'adapter — **rien d'autre ne change**.
