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

Ces règles ne sont pas des vœux : elles sont **enforcées par le compilateur**
(lints `deny` dans `Cargo.toml` + `clippy.toml`). Un code qui les viole ne
passe ni `cargo clippy -D warnings` ni la CI.

1. Zéro `unwrap`/`expect`/`panic`/`todo!`/`unimplemented!` en code de prod
   (autorisés dans les tests via `clippy.toml`). Zéro `println!`/`dbg!` — les
   sorties passent par `tracing`.
2. `thiserror` dans `domain`/`infra` ; `anyhow` seulement dans `app` (frontières).
3. Erreurs publiques en `#[non_exhaustive]` + chaîne préservée (`#[source]`/`#[from]`).
4. « Parse, don't validate » : valider à la frontière, propager le type-preuve.
5. Pas de lock (`std::sync::Mutex`) tenu à travers un `.await`.
6. `tracing` pour les logs ; **jamais de PII en clair** (email, token…) dans les spans/logs.
7. Tout nouveau use case = test unitaire ; toute route = test d'intégration dans `app/tests/`.
8. Toute API publique est documentée (`///` — lint `missing_docs`). Documente le
   **pourquoi** (intention, invariants), pas la paraphrase de la signature.
9. **Fail-fast sur la config** : une config invalide (origine CORS mal formée,
   port non numérique…) fait échouer le démarrage avec une erreur claire —
   jamais de valeur « corrigée » ou ignorée silencieusement au runtime.
10. Désactiver un lint : `#[expect(lint, reason = "…")]` **uniquement**, portée
   minimale (l'item, pas le module), avec une raison réelle. `#[allow]` nu = refus
   en revue. Si tu poses plus d'un `#[expect]` pour la même cause, le design est
   probablement faux : corrige le design.

## Recette : ajouter une feature (ordre IMPOSÉ)

Toujours de l'intérieur vers l'extérieur — le domaine d'abord, le transport en
dernier. Ne jamais commencer par le handler.

1. **Domaine — modèle** : entité / value object dans `domain/src/model/`
   (newtype + `parse()` faillible si le type porte une contrainte) + tests unitaires.
2. **Domaine — port** (si la feature a besoin d'I/O) : trait dans
   `domain/src/ports/`, nommé par capacité métier, erreurs `thiserror` `#[non_exhaustive]`.
3. **Domaine — use case** : struct dans `domain/src/service/`, générique sur le
   port (`impl<R: MonPort>`), testé avec un adapter in-memory de test.
4. **Infra — adapter** : impl du port dans `infra/src/` + test de roundtrip.
5. **App — transport** : DTOs + handler + routes dans `app/src/http/`, mapping
   d'erreurs dans `error.rs`, montage dans `lib.rs`.
6. **Contrat** : documenter la route dans `../docs/API.md` (source de vérité) et
   prévenir la moitié Flutter si le contrat change.
7. **Tests d'intégration** : cas nominal + chaque cas d'erreur dans `app/tests/`.
8. **Validation** : la checklist « Avant de pousser » ci-dessous, tout vert.

Definition of Done : les 8 étapes, pas 6 sur 8. Une feature sans test
d'intégration ou sans mise à jour du contrat est **incomplète**.

## Anti-patterns — refus automatique en revue

- **`.clone()` réflexe** pour faire taire le borrow checker sans comprendre.
  D'abord : une référence suffit-elle ? un `&str` au lieu de `String` ? Cloner
  un `Arc` est OK (compteur) ; cloner des données par confort, non.
- **Logique métier dans un handler** : le handler parse → appelle un use case →
  mappe la réponse. Rien d'autre. Un `if` métier dans `app/http/` est au mauvais étage.
- **Types du domaine sérialisés directement** sur le réseau (toujours un DTO).
- **`String`/`Uuid` nus** qui traversent les couches (toujours un newtype).
- **I/O bloquante dans un contexte async** (`std::fs`, `reqwest::blocking`,
  `std::thread::sleep`) : versions tokio ou `spawn_blocking`.
- **`tokio::spawn` orphelin** : toute tâche spawnée a un propriétaire qui gère
  son `JoinHandle` (ou une raison documentée de ne pas le faire).
- **Collection non paginée** : toute nouvelle route qui liste doit être paginée
  dès le départ (le `GET /users` du template est un témoin minimal, pas un modèle).
- **Suppression de lint en masse** (`#![allow(...)]` au niveau crate/module).
- **Fichier fourre-tout** : un module qui dépasse ~300 lignes hors tests doit
  probablement être découpé.

## Dépendances : politique

- **N'ajoute PAS de crate sans nécessité démontrée.** D'abord : std ? une dep
  déjà présente ? 20 lignes de code local ?
- Toute nouvelle dep passe par `[workspace.dependencies]` (version unique,
  centralisée), jamais en direct dans un crate membre.
- Features minimales (`default-features = false` quand pertinent) — chaque
  feature inutile coûte du temps de compil et de la surface d'attaque.
- `cargo deny check` doit rester vert (licences, advisories, doublons).
- Dans le doute sur une dep structurante (ORM, framework…), demande à David
  avant : c'est une décision d'architecture, pas un détail.

## Durcissement production (couche HTTP)

Le routeur (`app/src/lib.rs`) monte une stack de middlewares **non négociable** en
prod, construite depuis la config (`RouterConfig`). Ordre = request-id (externe)
→ trace → CORS → timeout → body-limit (interne) :

| Couche | Rôle | Réglage |
|---|---|---|
| `SetRequestId` + `PropagateRequestId` | corrélation des traces (`x-request-id`) | auto (UUID) |
| `TraceLayer` | logs structurés par requête | `RUST_LOG` / config |
| `CorsLayer` | autorise le front web cross-origin | `APP_HTTP__ALLOWED_ORIGINS` — **vide ⇒ permissif (dev only)**, à restreindre en prod. Origine mal formée ⇒ **échec au démarrage** (fail-fast) |
| `TimeoutLayer` | borne un handler lent → `408` | `APP_HTTP__REQUEST_TIMEOUT_SECS` (déf. 30) |
| `RequestBodyLimitLayer` | anti-DoS sur le corps → `413` | `APP_HTTP__MAX_BODY_BYTES` (déf. 2 Mio) |

Plus : **graceful shutdown** (`main.rs` écoute `SIGTERM`/Ctrl-C et draine les
requêtes en vol — requis en conteneur/k8s) et **logs structurés**
(`APP_LOG__FORMAT=json` en prod pour l'ingestion par un collecteur ; `text` en dev).

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
