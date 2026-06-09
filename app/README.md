# app/ — application Flutter

Partie Flutter du monorepo `rust-flutter-base`. Clean architecture, feature-first,
MVVM + Riverpod, Result typé. Parle au backend Rust **en HTTP/REST** (client Dio
isolé derrière une datasource par feature) — pas de FFI.

## Prérequis

- Flutter ≥ 3.24, Dart ≥ 3.5.
- Le backend Rust lancé (`cd rust && cargo run`, écoute sur `:8080`) pour un run
  end-to-end. Sans lui, l'UI tourne mais l'appel `greeting` remonte une erreur
  réseau typée (`NetworkFailure`).

## Démarrage

```bash
cd app
flutter create .              # régénère les dossiers natifs (non versionnés)
flutter pub get
flutter run -t lib/main_development.dart
```

> `flutter create .` est nécessaire au premier clone car `android/ ios/ …` ne
> sont pas versionnés (cf. `.gitignore` racine, ils sont régénérables).

## Flavors & base URL backend

La base URL du backend Rust est résolue **par flavor** (jamais en dur) :

| Flavor   | Entrypoint                  | Base URL                                  |
|----------|-----------------------------|-------------------------------------------|
| dev      | `lib/main_development.dart` | `http://10.0.2.2:8080` (émulateur Android), `http://127.0.0.1:8080` (iOS sim / desktop / web) |
| staging  | `lib/main_staging.dart`     | `https://api.staging.example.com` (placeholder) |
| prod     | `lib/main_production.dart`  | `https://api.example.com` (placeholder)   |

Pour un device physique sur le réseau local, surcharger l'URL dev au build :

```bash
flutter run -t lib/main_development.dart \
  --dart-define=API_BASE_URL=http://192.168.1.20:8080
```

## Structure

```
lib/
├── bootstrap.dart            # init commune (error zone, ProviderScope, runApp)
├── main_development.dart     # entrypoint flavor dev
├── main_staging.dart         # entrypoint flavor staging
├── main_production.dart      # entrypoint flavor prod
├── app.dart                  # widget racine (MaterialApp.router, theme, l10n)
├── core/
│   ├── config/               # AppConfig (immuable, base URL par flavor)
│   ├── di/                   # providers Riverpod (composition root, dioProvider)
│   ├── error/                # Result<T>, Failure (dont NetworkFailure)
│   ├── network/              # createDio() (client HTTP transverse, baseUrl/flavor)
│   ├── routing/              # go_router
│   ├── theme/                # ThemeData centralisé
│   └── observability/        # logger
├── features/
│   └── greeting/             # feature témoin bout-en-bout (appelle le backend)
│       ├── greeting_providers.dart  # câblage Riverpod (domain/data restent purs)
│       ├── data/             # datasource HTTP (Dio) + repository impl
│       ├── domain/           # entity + repository (interface) + usecase (Dart pur)
│       └── presentation/     # view_model (+state) + view + widgets
└── l10n/                     # ARB (en, fr)

test/                         # miroir de lib/
integration_test/             # E2E
```

## La feature témoin `greeting`

Démontre le flux complet **presentation → domain → data → HTTP → backend Rust** :

`GreetingScreen` (View) → `GreetingViewModel` (Notifier, expose `GreetingState`)
→ `GetGreeting` (UseCase, valide l'input) → `GreetingRepository` (interface) →
`GreetingRepositoryImpl` (mappe vers l'entité, convertit l'erreur réseau en
`Result`/`NetworkFailure`) → `GreetingHttpDataSource` (`Dio`) →
`GET /api/v1/greeting?name=...` sur le backend Rust.

Contrat (le backend fait foi) : `200 {"message":"Bonjour, <name> ! 👋"}` ;
`name` absent/vide ⇒ `{"message":"Bonjour, monde ! 👋"}`.

C'est le patron à copier pour toute nouvelle feature. Le backend expose aussi
`GET/POST /api/v1/users` (+ `GET /api/v1/users/{id}`) pour un exemple plus riche
(POST 201, 404) — même patron : nouvelle datasource + DTO + repository.

## Tests

```bash
flutter test                 # unit + widget
flutter test integration_test
```
