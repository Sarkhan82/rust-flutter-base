import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:rust_flutter_base/core/config/app_config.dart';
import 'package:rust_flutter_base/core/observability/logger.dart';

/// Construit le client HTTP transverse vers le backend Rust.
///
/// Frontière transport unique : toute la feature `greeting` (et les futures
/// features) tapent le backend via ce `Dio`. La `baseUrl` vient **toujours** du
/// [AppConfig] courant (flavor) — jamais en dur dans une datasource.
///
/// Fonction pure (pas de Riverpod) → testable et réutilisable hors DI.
Dio createDio(AppConfig config, AppLogger logger) {
  final dio = Dio(
    BaseOptions(
      baseUrl: config.apiBaseUrl,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      sendTimeout: const Duration(seconds: 5),
      headers: const {'Accept': 'application/json'},
    ),
  );
  // Dio lève par défaut une DioException sur tout status ≥ 400 : on la catch à
  // la frontière I/O (repository) pour la mapper en Failure typé.

  // Point d'extension AUTH (cf. FLUTTER_ARCHITECTURE.md §10) : quand une
  // feature auth existe, ajouter ici un interceptor qui injecte l'en-tête
  // `Authorization: Bearer <token>` (lu depuis un secure storage) et gère le
  // refresh sur 401. Hors-scope du scaffold (pas encore de feature auth).

  // Observabilité (cf. §12) : DEBUG uniquement, et on logge le `path` — jamais
  // l'URI complète (la query string peut contenir de la PII, ex. ?name=) ni le
  // payload. En prod, brancher Sentry/Crashlytics dans AppLogger plutôt que ça.
  if (kDebugMode) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          logger.info('HTTP → ${options.method} ${options.path}');
          handler.next(options);
        },
        onError: (error, handler) {
          logger.error(
            'HTTP ✗ ${error.requestOptions.method} '
            '${error.requestOptions.path} '
            '(${error.response?.statusCode ?? error.type.name})',
            error,
          );
          handler.next(error);
        },
      ),
    );
  }

  return dio;
}
