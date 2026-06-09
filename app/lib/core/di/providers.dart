import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rust_flutter_base/core/config/app_config.dart';
import 'package:rust_flutter_base/core/network/dio_client.dart';
import 'package:rust_flutter_base/core/observability/logger.dart';

/// Composition root des dépendances transverses.
///
/// Les providers spécifiques à une feature vivent dans la feature elle-même
/// (feature-first), pas ici.

/// Config de l'app. **Overridé au boot** par le flavor courant
/// (voir `bootstrap.dart`). Échoue volontairement si non overridé.
final appConfigProvider = Provider<AppConfig>(
  (ref) => throw UnimplementedError(
    'appConfigProvider doit être overridé dans bootstrap() avec le flavor.',
  ),
);

/// Logger applicatif.
final loggerProvider = Provider<AppLogger>((ref) => const AppLogger());

/// Client HTTP transverse vers le backend Rust.
///
/// `baseUrl` résolu depuis le flavor courant ([appConfigProvider]). Toutes les
/// datasources des features dépendent de ce provider — jamais d'un `Dio`
/// instancié en dur. Dans les tests, on override plutôt la datasource de la
/// feature avec un fake/mock (pas besoin de toucher à ce provider).
final dioProvider = Provider<Dio>(
  (ref) => createDio(
    ref.watch(appConfigProvider),
    ref.watch(loggerProvider),
  ),
);
