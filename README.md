# rust-flutter-base

Starter **monorepo Flutter + Rust** — clean architecture, prêt à cloner-démarrer.

Objectif : une base réutilisable pour démarrer une app Flutter dont la logique
lourde (calcul, crypto, parsing, moteur métier) vit dans un cœur **Rust**
partagé, consommé via FFI.

## Layout

```
rust-flutter-base/
├── app/      # Application Flutter (clean architecture)  — voir app/README.md
├── rust/     # Cœur Rust (crate(s) FFI)                  — voir rust/README.md
└── .github/  # CI
```

| Partie | Owner | État |
|--------|-------|------|
| `app/` (Flutter) | flutter-architect | Scaffold initial : feature témoin `greeting` de bout en bout, Rust isolé derrière une interface (`RustBridge`). |
| `rust/` (Rust)   | rust-architect   | À intégrer. L'app fonctionne et se teste avec une impl factice en attendant. |

## Intégration Rust ↔ Flutter

Le contrat est isolé dans `app/lib/core/rust/rust_bridge.dart` (interface
`RustBridge`). Aujourd'hui une implémentation **factice** (`FakeRustBridge`) est
injectée → l'app compile et passe ses tests **sans** la partie Rust.

Quand le cœur Rust est prêt, on branche la vraie implémentation (probablement
via [`flutter_rust_bridge`](https://pub.dev/packages/flutter_rust_bridge)) en
overridant un seul provider — **aucune autre couche ne change**. Voir
`app/lib/core/rust/README` (commentaires en tête de `rust_bridge.dart`).

> ⚠️ Le contrat exact (signatures Rust exposées, FRB vs UniFFI vs FFI brut) est
> à réconcilier avec rust-architect. L'interface actuelle (`greet(name)`) est un
> placeholder qui démontre le câblage end-to-end.

## Démarrage

```bash
cd app
flutter create .           # (re)génère les dossiers natifs android/ ios/ … (non versionnés)
flutter pub get
flutter run --flavor development -t lib/main_development.dart   # ou: flutter run -t lib/main_development.dart
```

Voir [`app/README.md`](app/README.md) et [`app/CLAUDE.md`](app/CLAUDE.md) pour
les conventions d'architecture.
