import 'package:dio/dio.dart';

import 'package:rust_flutter_base/core/error/failure.dart';
import 'package:rust_flutter_base/core/error/result.dart';
import 'package:rust_flutter_base/core/observability/logger.dart';
import 'package:rust_flutter_base/features/greeting/data/datasources/greeting_remote_data_source.dart';
import 'package:rust_flutter_base/features/greeting/domain/entities/greeting.dart';
import 'package:rust_flutter_base/features/greeting/domain/repositories/greeting_repository.dart';

/// Implémentation du [GreetingRepository] (couche data).
///
/// Frontière I/O : c'est **ici** qu'on `try/catch` et qu'on convertit toute
/// exception technique (réseau, HTTP, parsing) en [Failure] typé. Aucune
/// exception ne remonte au-delà de cette couche.
class GreetingRepositoryImpl implements GreetingRepository {
  const GreetingRepositoryImpl(this._dataSource, this._logger);

  final GreetingRemoteDataSource _dataSource;
  final AppLogger _logger;

  @override
  Future<Result<Greeting>> fetchGreeting(String name) async {
    try {
      final message = await _dataSource.fetchGreeting(name);
      return Ok(Greeting(message: message));
    } on DioException catch (e) {
      return Err(_mapDioError(e));
    } on FormatException catch (e, stack) {
      // Réponse qui ne respecte pas le contrat d'API. Le détail technique est
      // LOGGÉ (debuggable), jamais transporté dans le Failure (cf. §2/§10).
      _logger.error('Réponse backend malformée (greeting)', e, stack);
      return const Err(NetworkFailure(NetworkFailureKind.malformedResponse));
    } on Exception catch (e, stack) {
      // Filet de sécurité : erreur non anticipée.
      _logger.error('Erreur inattendue (greeting)', e, stack);
      return const Err(UnexpectedFailure());
    }
  }

  /// Catégorise l'échec Dio en cause typée. La traduction en message
  /// affichable vit en présentation (`FailureL10n`), pas ici.
  NetworkFailure _mapDioError(DioException e) {
    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        const NetworkFailure(NetworkFailureKind.timeout),
      DioExceptionType.connectionError =>
        const NetworkFailure(NetworkFailureKind.connection),
      DioExceptionType.badResponse => NetworkFailure(
          NetworkFailureKind.badResponse,
          statusCode: e.response?.statusCode,
        ),
      _ => const NetworkFailure(NetworkFailureKind.unexpected),
    };
  }
}
