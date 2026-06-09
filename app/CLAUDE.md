# CLAUDE.md — partie Flutter (`app/`)

Règles d'architecture et conventions de la partie Flutter du monorepo
`rust-flutter-base`. Le **pourquoi** détaillé et les sections numérotées
(`§N`) citées dans le code sont dans `docs/FLUTTER_ARCHITECTURE.md`.
**Ces règles priment** (elles sont la version courte, opérationnelle).

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

## Intégration Rust (HTTP/REST — pas de FFI)

- L'app parle au backend Rust **uniquement via HTTP/REST** : deux process
  distincts. **Pas de FFI.** Le backend est la source de vérité du contrat
  d'API (cf. CLAUDE.md racine).
- Client HTTP transverse = **Dio**, construit par `dioProvider`
  (`core/di/providers.dart`) via `createDio()` (`core/network/dio_client.dart`).
  Sa `baseUrl` vient **toujours** du flavor courant (`AppConfig.apiBaseUrl`),
  jamais en dur.
- Chaque feature accède au backend via une **datasource** dédiée qui injecte le
  `Dio` (ex : `GreetingHttpDataSource` derrière l'interface
  `GreetingRemoteDataSource`). Le chemin de version `/api/v1` est porté par la
  datasource (bumper l'API = changer la datasource, pas la config).
- Mapping erreur : la datasource peut lever (`DioException`, `FormatException`) ;
  le **repository** catch à la frontière I/O et convertit en `NetworkFailure`.
  Aucune exception réseau ne remonte au domaine/UI.
- **Base URL par flavor** : `dev` (backend local `:8080`, plateforme-aware —
  `10.0.2.2` émulateur Android, `127.0.0.1` iOS sim/desktop, surchargeable via
  `--dart-define=API_BASE_URL=...`), `staging`, `prod`. Un entrypoint
  `lib/main_<flavor>.dart` par flavor.
- Tests : on override la **datasource** de la feature
  (`greetingRemoteDataSourceProvider`) avec un fake/mock — pas besoin de toucher
  à `dioProvider` ni de réseau réel.

## State management

- **Riverpod 3, API manuelle** (`Notifier` / `NotifierProvider`) — pas de
  `riverpod_generator` dans ce scaffold (zéro `build_runner`).
- **Un seul** système de state management. Pas de Bloc en parallèle.
- `ref.watch` dans `build`, `ref.read` dans les callbacks/actions.

## Conventions de nommage

- Fichiers `snake_case`. Types `PascalCase`. Membres `camelCase`.
- Suffixes : `...Screen`, `...ViewModel`, `...State`, `...Repository`,
  `...DataSource`, `...Dto`, `...UseCase` (classe `call()`).
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
- **Mock à la frontière** (datasources HTTP), jamais la logique métier.
  `mocktail` + overrides de providers Riverpod (override la datasource de la
  feature, pas `dioProvider`).

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
