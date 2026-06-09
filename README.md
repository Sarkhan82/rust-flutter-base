# rust-flutter-base

Starter **monorepo Flutter + Rust** — clean architecture, prêt à cloner-démarrer.

Objectif : une base réutilisable pour démarrer une app **Flutter mobile-first**
qui parle à un **backend Rust** via **HTTP/REST** (GraphQL-ready). Deux moitiés
découplées, chacune avec sa propre architecture propre et sa CI.

## Layout

```
rust-flutter-base/
├── app/      # Application Flutter (clean architecture, mobile-first) — voir app/README.md
├── rust/     # Backend API Rust (axum, hexagonal)                     — voir rust/README.md
├── docs/     # RUST_ARCHITECTURE.md — le guide d'archi de référence
└── .github/  # CI séparée par moitié (Flutter / Rust)
```

| Partie | Owner | État |
|--------|-------|------|
| `app/` (Flutter) | flutter-architect | Feature témoin `greeting` de bout en bout ; accès au backend isolé derrière une interface. |
| `rust/` (Rust)   | rust-architect   | Service axum hexagonal. Feature `greeting` + ressource `users` complète. CI verte. |

## Intégration Flutter ↔ Rust — **HTTP/REST**

Le frontend Flutter consomme le backend Rust **uniquement via HTTP**. Pas de FFI :
deux process, deux déploiements, contrat = l'API REST versionnée (`/api/v1/...`).

- **Source de vérité du contrat = le backend** (`rust/`). Voir le tableau des
  routes dans [`rust/README.md`](rust/README.md).
- Côté Flutter, l'accès réseau est isolé derrière une interface de data source ;
  la base URL est **configurable par flavor** (dev/staging/prod), jamais en dur.
- Feature témoin de bout en bout : `GET /api/v1/greeting?name=...` →
  `{"message":"Bonjour, ... ! 👋"}`, affichée par l'écran `greeting` de l'app.

## Démarrage

**Backend :**
```bash
cd rust
cargo run -p app     # http://127.0.0.1:8080 — adapter in-memory, aucune infra requise
```

**App Flutter :**
```bash
cd app
flutter create .     # (re)génère les dossiers natifs android/ ios/ … (non versionnés)
flutter pub get
flutter run -t lib/main_development.dart   # pointe la base URL sur le backend local
```

Conventions : [`rust/CLAUDE.md`](rust/CLAUDE.md), [`app/CLAUDE.md`](app/CLAUDE.md),
et le guide [`docs/RUST_ARCHITECTURE.md`](docs/RUST_ARCHITECTURE.md).
