# app/ — application Flutter

Partie Flutter du monorepo `rust-flutter-base`. Clean architecture, feature-first,
MVVM + Riverpod, Result typé, Rust isolé derrière une interface.

## Prérequis

- Flutter ≥ 3.24, Dart ≥ 3.5.

## Démarrage

```bash
cd app
flutter create .              # régénère les dossiers natifs (non versionnés)
flutter pub get
flutter run -t lib/main_development.dart
```

> `flutter create .` est nécessaire au premier clone car `android/ ios/ …` ne
> sont pas versionnés (cf. `.gitignore` racine, ils sont régénérables).

## Structure

```
lib/
├── bootstrap.dart            # init commune (error zone, ProviderScope, runApp)
├── main_development.dart     # entrypoint flavor dev
├── main_production.dart      # entrypoint flavor prod
├── app.dart                  # widget racine (MaterialApp.router, theme, l10n)
├── core/
│   ├── config/               # AppConfig (immuable, par flavor)
│   ├── di/                   # providers Riverpod (composition root)
│   ├── error/                # Result<T>, Failure
│   ├── routing/              # go_router
│   ├── theme/                # ThemeData centralisé
│   ├── rust/                 # RustBridge (interface) + FakeRustBridge
│   └── observability/        # logger
├── features/
│   └── greeting/             # feature témoin de bout en bout (appelle Rust)
│       ├── greeting_providers.dart  # câblage Riverpod (domain/data restent purs)
│       ├── data/             # service (wrappe RustBridge) + repository impl
│       ├── domain/           # entity + repository (interface) + usecase (Dart pur)
│       └── presentation/     # view_model (+state) + view + widgets
└── l10n/                     # ARB (en, fr)

test/                         # miroir de lib/
integration_test/             # E2E
```

## La feature témoin `greeting`

Démontre le flux complet **presentation → domain → data → Rust** :

`GreetingScreen` (View) → `GreetingViewModel` (Notifier, expose `GreetingState`)
→ `GetGreeting` (UseCase, valide l'input) → `GreetingRepository` (interface) →
`GreetingRepositoryImpl` (mappe vers l'entité, gère l'erreur en `Result`) →
`RustGreetingService` (wrappe `RustBridge`) → `RustBridge` (impl factice
aujourd'hui, vrai Rust demain).

C'est le patron à copier pour toute nouvelle feature.

## Tests

```bash
flutter test                 # unit + widget
flutter test integration_test
```
