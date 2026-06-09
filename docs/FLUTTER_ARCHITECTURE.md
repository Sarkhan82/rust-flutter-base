# FLUTTER_ARCHITECTURE.md — guide d'architecture (partie `app/`)

Doc de référence de la partie Flutter du monorepo `rust-flutter-base`.
Symétrique de `RUST_ARCHITECTURE.md`. Les règles opérationnelles courtes vivent
dans `app/CLAUDE.md` (qui **prime** pour un agent) ; ce doc porte le **pourquoi**
et les sections numérotées référencées depuis le code (`cf. §N`).

Cible : base **production-grade**, **mobile-first**, **web-ready**, qui parle au
backend Rust **uniquement en HTTP/REST** (pas de FFI). GraphQL-ready : la
frontière réseau est isolée par feature, un swap REST→GraphQL ne touche qu'une
classe (la datasource).

---

## §1 — Couches et sens des dépendances

Clean architecture **feature-first**. Chaque feature : `lib/features/<feat>/`
avec `data/ domain/ presentation/` + un fichier de câblage
`<feat>_providers.dart`.

```
presentation → domain ← data
```

- **`domain/`** : entités, interfaces de repository, use cases. **Dart pur** —
  zéro import Flutter/Riverpod/Dio. C'est le cœur stable, indépendant des
  frameworks et du transport.
- **`data/`** : datasources (HTTP), DTO, implémentations de repository. Dépend
  du domaine (implémente ses interfaces), jamais l'inverse.
- **`presentation/`** : `View` (widgets, zéro logique métier) + `ViewModel`
  (Riverpod `Notifier`, expose un `State` immuable).

**Règle de dépendance non négociable** : `domain/` et `data/` n'importent
**jamais** `flutter_riverpod`. Le câblage (qui matérialise `presentation →
domain → data`) est isolé dans `<feat>_providers.dart` — seul endroit où
Riverpod assemble le graphe. Vérification CI-able :

```bash
grep -rn "flutter_riverpod\|package:riverpod" lib/features/*/domain/ lib/features/*/data/
# → doit être vide
```

**Pourquoi** : un domaine pur est testable sans pump de widget, réutilisable
hors Flutter (CLI, isolate, autre front), et ne casse pas quand on change de
state manager ou de transport.

---

## §2 — Erreurs typées : `Result`, jamais d'exception qui fuit

Toute opération faillible renvoie `Result<T>` (`core/error/result.dart`, `sealed`
→ `switch` exhaustif garanti par le compilateur). La hiérarchie d'échecs
(`core/error/failure.dart`, `sealed`) : `NetworkFailure`, `ValidationFailure`,
`UnexpectedFailure`.

- `try/catch` **uniquement** à la frontière I/O (repositories). Le repository
  convertit l'exception technique en `Failure` typé.
- **Aucune exception ne remonte** au domaine ni à l'UI.
- **Aucun détail technique** (message d'exception, stack, payload) ne finit dans
  un `Failure.message` affiché : message présentable côté UI, détail technique
  → log (cf. §12). Ne jamais interpoler `$e` dans un message destiné à l'écran.

---

## §3 — State management

Riverpod 3, **API manuelle** (`Notifier`/`NotifierProvider`) — pas de
`riverpod_generator` dans ce scaffold (zéro `build_runner`, éditable à la main).
Un seul système de state management (pas de Bloc en parallèle). `ref.watch` dans
`build`, `ref.read` dans les callbacks. Bascule codegen documentée dans
`app/CLAUDE.md`.

---

## §4 — DI / composition root

DI explicite via Riverpod, rien instancié en dur.
- Dépendances **transverses** : `core/di/providers.dart` (`appConfigProvider`,
  `loggerProvider`, `dioProvider`).
- Câblage **par feature** : `features/<feat>/<feat>_providers.dart`.
- `appConfigProvider` lève si non overridé → force le boot par flavor
  (`bootstrap.dart`) à fournir la config. Échec bruyant > config fantôme.

---

## §5 — Intégration backend Rust (HTTP/REST)

- Deux process distincts. **Pas de FFI.** Le backend est la **source de vérité**
  du contrat d'API (cf. `CLAUDE.md` racine + `RUST_ARCHITECTURE.md`).
- Client HTTP transverse = **Dio**, construit par `createDio()`
  (`core/network/dio_client.dart`), exposé via `dioProvider`. `baseUrl` issue
  **toujours** du flavor (`AppConfig.apiBaseUrl`), jamais en dur.
- Chaque feature : une **datasource** dédiée qui injecte le `Dio` et porte le
  chemin de version `/api/vN` (bumper l'API = changer la datasource, pas la
  config). Le repository mappe `DioException`/`FormatException` → `NetworkFailure`.
- Tests : override la **datasource** de la feature (mock), pas `dioProvider` ni
  de réseau réel.

---

## §6 — Config & flavors

`Flavor { development, staging, production }`, un entrypoint
`lib/main_<flavor>.dart` chacun, une factory `AppConfig.<flavor>()`.
`AppConfig` est immuable (`Equatable`). Base URL résolue par flavor ; dev
plateforme-aware (`10.0.2.2` émulateur Android vs `127.0.0.1` iOS sim/desktop/web)
et surchargeable `--dart-define=API_BASE_URL=...` pour un device physique.

---

## §7 — Theming & a11y

Theming centralisé (`core/theme/`, Material 3, `ColorScheme.fromSeed`). Aucune
couleur/taille en dur ailleurs → `Theme.of(context)`. Cibles tactiles ≥ 48 dp.
Mobile-first : largeur de contenu bornée (`ConstrainedBox(maxWidth: 480)`) pour
rester lisible sur viewport web/desktop large.

---

## §8 — Routing & guards d'auth

Routing déclaratif `go_router`, exposé en provider (`routerProvider`, testable,
overridable). Noms de routes centralisés (`Routes`), pas de chaînes magiques
dispersées.

**Auth (point d'extension)** : quand une feature auth existe, ajouter les guards
via `GoRouter.redirect` qui lit l'état de session (un `authStateProvider`) et
renvoie vers `/login` si non authentifié. Garder le `redirect` pur (pas d'I/O) :
il observe un état déjà résolu, il ne déclenche pas le login.

---

## §9 — Localisation

i18n via `flutter_localizations` + ARB (`lib/l10n/app_*.arb`), `gen-l10n` activé
(`generate: true`). Aucune string UI en dur → `AppLocalizations.of(context)`.
`intl: any` est volontaire (version épinglée par `flutter_localizations`).

---

## §10 — Sécurité

- **Aucun secret dans le binaire** : ni clé API, ni token, ni mot de passe dans
  `AppConfig`, le code ou les ARB. Un binaire client est inspectable. Les
  secrets vivent côté backend ; les tokens utilisateur dans un **secure storage**
  (`flutter_secure_storage` : Keychain iOS / Keystore Android).
- **Transport** : `https://` obligatoire hors dev. Android bloque le cleartext
  (`http://`) en release par défaut — le `http://` n'est toléré que pour le
  backend local en dev. Pour un device dev sur réseau local, passer par
  `--dart-define` (cf. §6), ne jamais committer une IP en dur.
- **Token d'auth (point d'extension)** : injecter un interceptor Dio qui ajoute
  le `Authorization: Bearer …` (lu depuis le secure storage) et gère le refresh
  sur `401`. Stub documenté dans `core/network/dio_client.dart`. Pour les API
  sensibles, envisager le **certificate pinning** (`badCertificateCallback` /
  `dio` + `IOHttpClientAdapter`).
- **Logs** : ne jamais logger de payload, de token, ni de query string (PII
  potentielle, ex. `?name=`). Logger méthode + **path** + status code, en debug
  seulement (cf. §12).
- **Validation d'entrée** côté domaine (use case) avant tout appel réseau ;
  ne jamais faire confiance à une réponse serveur non validée (parsing strict,
  `FormatException` si le contrat n'est pas respecté).

---

## §11 — Performance

- `const` partout où possible ; widgets en **classes**, pas en méthodes
  `_buildX()` (préserve l'identité d'instance → moins de rebuilds).
- Aucune logique (réseau/calcul lourd) dans `build()`.
- Granularité Riverpod : `select` pour ne rebuild que sur la portion d'état
  utile ; `ref.watch` ciblé.
- `Dio` est paresseux (construit à la 1re requête), réutilisé (pas de client par
  appel) ; timeouts bornés (connect/receive/send) pour ne pas bloquer l'UI.
- Listes : `ListView.builder` (lazy) ; images : cache + dimensions bornées.
- Calculs lourds → `compute`/isolate, jamais sur le thread UI.

---

## §12 — Observabilité

Logger applicatif derrière une interface (`core/observability/logger.dart`,
`AppLogger`) — jamais `print` (`avoid_print`). Niveaux info/warn/error.
- En **debug** : traces HTTP (méthode + path + status), sans query string ni
  payload.
- En **production** : brancher un backend (Sentry / Crashlytics) dans `AppLogger`
  et dans `FlutterError.onError` + `runZonedGuarded` (déjà câblés dans
  `bootstrap.dart`). L'interface reste mockable en test.

---

## §13 — Tests

Pyramide : surtout unit (use cases, repositories, mappers, ViewModels), puis
widget, puis integration. **Mock à la frontière** (datasources HTTP via
`mocktail` + override de provider), jamais la logique métier. Tests miroir de
`lib/` sous `test/`, suffixe `_test.dart`. CI : `dart format --set-exit-if-changed`,
`flutter analyze` (0 issue), `flutter test`.

---

## §14 — Anti-over-engineering

La structure en couches est un coût ; elle se justifie quand chaque couche porte
une vraie responsabilité.
- Un use case qui ne fait que `return repo.x()` (pass-through) est du bruit —
  soit il porte une vraie logique (validation, orchestration, ex. `GetGreeting`
  valide l'input), soit la presentation appelle le repository directement.
- Pas de DTO séparé si l'entité domaine suffit ET que le mapping est trivial ;
  introduire le DTO dès que la forme réseau diverge de l'entité.
- Pas d'abstraction « au cas où » : on isole derrière une interface ce qu'on
  prévoit de mocker ou de remplacer (datasource, logger), pas tout par principe.

**Pourquoi** : une base sur-abstraite est aussi coûteuse à faire évoluer qu'une
base sans structure. La règle : abstraire ce qui varie ou se teste, pas le reste.
