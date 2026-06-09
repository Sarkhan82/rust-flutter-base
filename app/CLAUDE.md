# CLAUDE.md — partie Flutter (`app/`)

Règles d'architecture et conventions de la partie Flutter du monorepo
`rust-flutter-base`. Dérivé de `FLUTTER_ARCHITECTURE.md` (doc de référence).
**Ces règles priment.**

## Architecture

- **Clean architecture en couches**, **feature-first**. Chaque feature vit dans
  `lib/features/<feature>/` avec ses sous-couches `data/ domain/ presentation/`.
- **Sens des dépendances** : `presentation → domain → data`. La couche UI ne
  connaît jamais un DTO ni un détail réseau/FFI. Le domaine ne dépend de rien.
- **MVVM** côté UI : `View` (widgets, zéro logique métier) + `ViewModel`
  (Riverpod `Notifier`, expose un `State` immuable).
- **Result, pas d'exception qui fuit** : toute opération faillible renvoie
  `Result<T>` (`core/error/result.dart`). `try/catch` uniquement à la frontière
  I/O (repositories / services). Le `switch` exhaustif sur `Result` est garanti
  par le compilateur.
- **DI explicite via Riverpod** : rien instancié en dur. Les dépendances
  transverses passent par `core/di/providers.dart` ; le câblage propre à une
  feature vit dans `features/<feature>/<feature>_providers.dart`.
- **Domaine = Dart pur** : les classes de `domain/` (et `data/`) n'importent
  **pas** Riverpod et ne référencent jamais une couche plus basse. Les providers
  qui les assemblent sont isolés dans le fichier `<feature>_providers.dart` —
  seul endroit où le sens `presentation → domain → data` est matérialisé. Une
  classe domaine qui `import 'flutter_riverpod'` ou un fichier `data/` est un
  bug d'architecture.

## Intégration Rust

- Le cœur Rust est consommé **uniquement** via l'interface `RustBridge`
  (`core/rust/rust_bridge.dart`). Aucune couche ne référence directement les
  bindings FFI.
- Impl courante : `FakeRustBridge` (factice), injectée par `rustBridgeProvider`.
- Pour brancher le vrai Rust : implémenter `RustBridge` avec les bindings
  générés et **overrider `rustBridgeProvider`** au boot. Rien d'autre ne change.

## State management

- **Riverpod 3, API manuelle** (`Notifier` / `NotifierProvider`) — pas de
  `riverpod_generator` dans ce scaffold (zéro `build_runner`).
- **Un seul** système de state management. Pas de Bloc en parallèle.
- `ref.watch` dans `build`, `ref.read` dans les callbacks/actions.

## Conventions de nommage

- Fichiers `snake_case`. Types `PascalCase`. Membres `camelCase`.
- Suffixes : `...Screen`, `...ViewModel`, `...State`, `...Repository`,
  `...Service`, `...Dto`, `...UseCase` (classe `call()`).
- Tests : miroir de `lib/` sous `test/`, suffixe `_test.dart`.

## Règles de code

- `const` partout où possible. Widgets en **classes**, pas en méthodes
  `_buildX()`.
- Modèles/états **immuables** (`Equatable` pour l'égalité de valeur).
- Pas de logique (réseau/FFI/calcul lourd) dans `build()`.
- Après un `await`, `if (!context.mounted) return;` avant de toucher au
  `BuildContext`.
- Aucune string UI en dur → `AppLocalizations` (ARB dans `lib/l10n/`).
- Aucune couleur/taille en dur → `Theme.of(context)` / tokens de `core/theme/`.
- `avoid_print` : utiliser un logger.

## Tests

- Pyramide : surtout du unit (ViewModels, UseCases, Repositories, mappers),
  puis widget, puis integration.
- **Mock à la frontière** (`RustBridge` / services), jamais la logique métier.
  `mocktail` + overrides de providers Riverpod.

## Bascule codegen (optionnelle, quand le SDK + build_runner sont dispo)

Le scaffold est volontairement sans codegen pour être éditable à la main. Pour
passer à l'échelle :
1. Ajouter `freezed`, `freezed_annotation`, `json_serializable`,
   `build_runner`, `riverpod_generator`, `riverpod_annotation` en
   `dev_dependencies`/`dependencies`.
2. Migrer les `State`/entités vers `@freezed`, les ViewModels vers
   `@riverpod`.
3. `dart run build_runner build --delete-conflicting-outputs`.

## Plateformes

Les dossiers natifs (`android/ ios/ linux/ macos/ windows/ web/`) ne sont pas
versionnés (régénérables). `flutter create .` dans `app/` les (re)génère depuis
`pubspec.yaml`.
