import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

/// Environnements de build (flavors).
///
/// Chaque flavor a un entrypoint dédié (`lib/main_<flavor>.dart`) et une
/// factory `AppConfig.<flavor>()`. La base URL du backend Rust en dépend.
enum Flavor { development, staging, production }

/// Configuration immuable injectée au démarrage (un par flavor).
///
/// Aucun secret ici : les secrets vivent côté backend / dans le stockage
/// sécurisé, jamais en dur dans le binaire (cf. FLUTTER_ARCHITECTURE.md §10).
///
/// `apiBaseUrl` est **toujours** résolu par flavor — jamais en dur dans la
/// couche réseau. Le `dioProvider` (`core/di/providers.dart`) le lit ici.
class AppConfig extends Equatable {
  const AppConfig({
    required this.flavor,
    required this.appName,
    required this.apiBaseUrl,
  });

  /// Config du flavor **development**.
  ///
  /// La base URL dev cible le backend Rust local (`port 8080`). Elle dépend de
  /// la plateforme : l'émulateur Android atteint l'hôte via `10.0.2.2`, le
  /// simulateur iOS / desktop via `127.0.0.1`. Surchargeable au build :
  /// `flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8080`
  /// (utile pour un device physique sur le réseau local).
  factory AppConfig.development() => AppConfig(
        flavor: Flavor.development,
        appName: 'RustFlutterBase (dev)',
        apiBaseUrl: _devBaseUrl(),
      );

  /// Config du flavor **staging**.
  ///
  /// Sur web (build servi par le conteneur applicatif ou proxifié par le
  /// gateway, cf. `_webSameOriginBaseUrl`), la baseUrl est **relative**
  /// (same-origin). Sur mobile natif (hors proxy), elle reste absolue.
  factory AppConfig.staging() => AppConfig(
        flavor: Flavor.staging,
        appName: 'RustFlutterBase (staging)',
        apiBaseUrl:
            kIsWeb ? _webSameOriginBaseUrl() : 'https://api.staging.example.com',
      );

  /// Config de **production**. Cf. doc `AppConfig.staging` pour la
  /// résolution web same-origin.
  factory AppConfig.production() => AppConfig(
        flavor: Flavor.production,
        appName: 'RustFlutterBase',
        apiBaseUrl: kIsWeb ? _webSameOriginBaseUrl() : 'https://api.example.com',
      );

  final Flavor flavor;
  final String appName;

  /// Racine du backend Rust (sans `/api/v1` : le chemin de version est porté
  /// par les datasources, pour pouvoir bumper `/api/vN` au même endroit).
  final String apiBaseUrl;

  bool get isProduction => flavor == Flavor.production;

  /// Résout la base URL de dev : override `--dart-define` prioritaire, sinon
  /// défaut plateforme-aware (Android émulateur vs iOS sim / desktop / web).
  static String _devBaseUrl() {
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) return override;
    // `defaultTargetPlatform` est web-safe (≠ `dart:io Platform`).
    final isAndroidEmulator =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    return isAndroidEmulator ? 'http://10.0.2.2:8080' : 'http://127.0.0.1:8080';
  }

  /// URL API **relative same-origin** pour le web (US-628, couche B).
  ///
  /// Quand le front est servi par le conteneur applicatif lui-même
  /// (Dockerfile multi-stage, `#628`) ou proxifié par le gateway Praxek
  /// (`/api/v1/apps/<name>/*`, cf. `appproxy.go` dans le repo `praxek`), le
  /// front et l'API partagent la MÊME origine. Une `baseUrl` **sans schéma ni
  /// host** (ex. `/api/v1/apps/tasks`) est résolue par Dio (web →
  /// `XMLHttpRequest`) contre `window.location.origin` : les requêtes
  /// restent same-origin/same-site → le cookie de session part avec chaque
  /// appel (pas de 401 cross-origin). C'est CE fix qui débloque l'auth
  /// derrière le proxy — pas le Dockerfile, pas le `base-href` (qui ne gère
  /// que les assets).
  ///
  /// `<name>` = slug de l'app, injecté au build, jamais en dur :
  /// `flutter build web --dart-define=APP_NAME=tasks`. Surchargeable comme
  /// le reste via `--dart-define=API_BASE_URL=...` (ex. pour un `flutter run
  /// -d chrome` local qui doit taper un backend séparé, cross-origin,
  /// intentionnellement).
  static String _webSameOriginBaseUrl() {
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) return override;
    const appSlug = String.fromEnvironment('APP_NAME', defaultValue: 'app');
    return '/api/v1/apps/$appSlug';
  }

  @override
  List<Object?> get props => [flavor, appName, apiBaseUrl];
}
