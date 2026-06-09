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

## Durcissement production (couche HTTP)

Le routeur (`app/src/lib.rs`) monte une stack de middlewares **non négociable** en
prod, construite depuis la config (`RouterConfig`). Ordre = request-id (externe)
→ trace → CORS → timeout → body-limit (interne) :

| Couche | Rôle | Réglage |
|---|---|---|
| `SetRequestId` + `PropagateRequestId` | corrélation des traces (`x-request-id`) | auto (UUID) |
| `TraceLayer` | logs structurés par requête | `RUST_LOG` / config |
| `CorsLayer` | autorise le front web cross-origin | `APP_HTTP__ALLOWED_ORIGINS` — **vide ⇒ permissif (dev only)**, à restreindre en prod |
| `TimeoutLayer` | borne un handler lent → `408` | `APP_HTTP__REQUEST_TIMEOUT_SECS` (déf. 30) |
| `RequestBodyLimitLayer` | anti-DoS sur le corps → `413` | `APP_HTTP__MAX_BODY_BYTES` (déf. 2 Mio) |

Plus : **graceful shutdown** (`main.rs` écoute `SIGTERM`/Ctrl-C et draine les
requêtes en vol — requis en conteneur/k8s).

Règles : toute nouvelle couche transverse se monte ici, pas dans un handler.
**CORS permissif interdit en prod** : renseigner les origines explicites.

## Authentification (point d'extension)

Le template n'embarque **aucune** authn/authz (volontaire). Pour l'ajouter :
middleware axum (`from_fn`/extractor) monté sur le sous-routeur `/api/v1`, qui
valide le token et injecte l'identité dans les extensions de requête. La logique
d'autorisation métier reste un use case du `domain` ; le transport ne fait que
porter le jeton. Ne jamais logguer le jeton (cf. règle PII).

## Avant de pousser

```bash
cargo fmt --all -- --check
cargo clippy --workspace --all-targets --all-features -- -D warnings
cargo test --workspace --all-features          # ou : cargo nextest run --workspace --all-features
cargo deny check                               # si cargo-deny installé
```

> La CI vérifie en plus le **MSRV** (`rust-version` dans `Cargo.toml`) via un job
> `cargo check` sur la version plancher. Si tu utilises une API plus récente,
> bumpe `rust-version` — sinon la CI casse.

La CI (`.github/workflows/rust-ci.yml`) rejoue tout ça. Un PR qui ne passe pas est bloqué.

## Étendre vers une vraie DB

L'adapter par défaut est `infra::InMemoryUserRepository`. Pour Postgres :
1. ajoute `sqlx` (feature `postgres`) dans `infra` ;
2. crée `infra/src/postgres/user_repo.rs` implémentant `domain::UserRepository` ;
3. `cargo sqlx prepare` → commite `.sqlx/` (sinon la CI casse, cf. §8.4 du guide) ;
4. dans `app/src/main.rs`, remplace la construction de l'adapter — **rien d'autre ne change**.
