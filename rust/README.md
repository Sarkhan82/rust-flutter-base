# rust/ — backend API Rust

Service HTTP (axum) en **architecture hexagonale**. C'est la source de vérité du
contrat d'API consommé par l'app Flutter (`../app/`).

## Layout (workspace cargo)

```
rust/
├── crates/
│   ├── domain/   # logique PURE : model (newtypes), ports (traits), service (use cases)
│   ├── infra/    # adapters concrets des ports + config (figment)
│   └── app/      # transport HTTP (axum), wiring, télémétrie — le binaire
├── Cargo.toml    # workspace + lints centralisés
├── clippy.toml · rustfmt.toml · deny.toml · rust-toolchain.toml
└── CLAUDE.md     # règles de contribution (condensé de ../docs/RUST_ARCHITECTURE.md)
```

Sens des dépendances : **toujours vers `domain`**. `domain` ne dépend d'aucune infra.

## Démarrer

```bash
cd rust
cargo run -p app        # serveur sur http://127.0.0.1:8080 (adapter in-memory, zéro infra requise)
```

## Contrat d'API (v1)

| Méthode & route | Réponse |
|---|---|
| `GET /health` | `200` `{"status":"ok"}` |
| `GET /api/v1/greeting?name=Alice` | `200` `{"message":"Bonjour, Alice ! 👋"}` (name absent/vide → `monde`) |
| `GET /api/v1/users` | `200` `[{"id":uuid,"email":...}]` |
| `POST /api/v1/users` `{"email":"a@b.com"}` | `201` `{"id":uuid,"email":...}` · email invalide → `422` |
| `GET /api/v1/users/{id}` | `200` `{...}` · inconnu → `404` |

`greeting` est la **feature témoin** branchée de bout en bout avec l'app Flutter.
`users` montre le pattern complet (port + adapter + use cases).

## Qualité

```bash
cargo fmt --all -- --check
cargo clippy --workspace --all-targets -- -D warnings
cargo test --workspace
```

Détails d'architecture et trade-offs : [`../docs/RUST_ARCHITECTURE.md`](../docs/RUST_ARCHITECTURE.md).
Postgres et autres extensions : voir `CLAUDE.md`.
