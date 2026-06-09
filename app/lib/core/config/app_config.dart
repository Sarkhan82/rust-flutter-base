import 'package:equatable/equatable.dart';

/// Environnements de build (flavors).
enum Flavor { development, staging, production }

/// Configuration immuable injectée au démarrage (un par flavor).
///
/// Aucun secret ici : les secrets vivent côté backend / dans le stockage
/// sécurisé, jamais en dur dans le binaire (cf. FLUTTER_ARCHITECTURE.md §10).
class AppConfig extends Equatable {
  const AppConfig({
    required this.flavor,
    required this.appName,
    required this.apiBaseUrl,
  });

  /// Config par défaut pour le flavor de développement.
  factory AppConfig.development() => const AppConfig(
        flavor: Flavor.development,
        appName: 'RustFlutterBase (dev)',
        apiBaseUrl: 'https://api.dev.example.com',
      );

  /// Config de production.
  factory AppConfig.production() => const AppConfig(
        flavor: Flavor.production,
        appName: 'RustFlutterBase',
        apiBaseUrl: 'https://api.example.com',
      );

  final Flavor flavor;
  final String appName;
  final String apiBaseUrl;

  bool get isProduction => flavor == Flavor.production;

  @override
  List<Object?> get props => [flavor, appName, apiBaseUrl];
}
