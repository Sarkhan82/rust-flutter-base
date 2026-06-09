import 'package:dio/dio.dart';

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

  // Observabilité légère : trace requêtes/erreurs sans fuiter de payload.
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        logger.info('HTTP → ${options.method} ${options.uri}');
        handler.next(options);
      },
      onError: (error, handler) {
        logger.error(
          'HTTP ✗ ${error.requestOptions.method} '
          '${error.requestOptions.uri} '
          '(${error.response?.statusCode ?? error.type.name})',
          error,
        );
        handler.next(error);
      },
    ),
  );

  return dio;
}
