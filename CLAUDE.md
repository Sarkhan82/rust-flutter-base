# rust-flutter-base — conventions monorepo

Base réutilisable **Flutter + Rust** communiquant en **HTTP/REST** (GraphQL-ready),
mobile-first.

## Layout

- `rust/` — backend API Rust (workspace cargo, hexagonal). Règles : `rust/CLAUDE.md`.
- `app/` — app Flutter (mobile-first, clean architecture). Règles : `app/CLAUDE.md`.
- `docs/` — `API.md` (**contrat d'API, source de vérité**), `RUST_ARCHITECTURE.md`
  et `FLUTTER_ARCHITECTURE.md` (guides d'archi de référence).

## Contrat d'intégration

- L'app Flutter parle au backend Rust **uniquement via HTTP/REST** (`/api/v1/...`).
  Pas de FFI : deux process distincts.
- **Le contrat est écrit dans `docs/API.md`** (backend faisant foi). Tout
  changement de route/DTO commence par ce fichier, puis est répercuté côté
  `rust/` et `app/` (et versionné via `/api/vN`).
- Base URL côté Flutter = configurable par flavor (dev/staging/prod), jamais en dur.
- Feature témoin bout-en-bout : `GET /api/v1/greeting?name=...`.

## Frontières d'agents

- **Backend Rust** (`rust/`) → agent `rust-architect`.
- **Frontend Flutter** (`app/`) → agent `flutter-architect`.
- Un changement de contrat d'API se coordonne entre les deux, le backend faisant foi.

## Qualité

Chaque moitié a sa propre CI dans `.github/workflows/` :
- `rust-ci.yml` — fmt + clippy (`-D warnings`) + tests + cargo-deny, sur `rust/`.
- `ci.yaml` — format + analyze + tests Flutter, sur `app/`.

Un PR doit passer les checks de la (des) moitié(s) qu'il touche.
