import 'package:dio/dio.dart';

import 'package:rust_flutter_base/core/error/failure.dart';
import 'package:rust_flutter_base/core/error/result.dart';
import 'package:rust_flutter_base/features/greeting/data/datasources/greeting_remote_data_source.dart';
import 'package:rust_flutter_base/features/greeting/domain/entities/greeting.dart';
import 'package:rust_flutter_base/features/greeting/domain/repositories/greeting_repository.dart';

/// Implémentation du [GreetingRepository] (couche data).
///
/// Frontière I/O : c'est **ici** qu'on `try/catch` et qu'on convertit toute
/// exception technique (réseau, HTTP, parsing) en [Failure] typé. Aucune
/// exception ne remonte au-delà de cette couche.
class GreetingRepositoryImpl implements GreetingRepository {
  const GreetingRepositoryImpl(this._dataSource);

  final GreetingRemoteDataSource _dataSource;

  @override
  Future<Result<Greeting>> fetchGreeting(String name) async {
    try {
      final message = await _dataSource.fetchGreeting(name);
      return Ok(Greeting(message: message));
    } on DioException catch (e) {
      return Err(NetworkFailure(_describeDioError(e)));
    } on Exception catch (e) {
      // FormatException (réponse malformée) et filet de sécurité.
      return Err(NetworkFailure('Réponse inattendue du serveur : $e'));
    }
  }

  /// Message présentable selon le type d'échec Dio (sans fuiter de détail
  /// technique inutile à l'utilisateur).
  String _describeDioError(DioException e) {
    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        'Le serveur met trop de temps à répondre.',
      DioExceptionType.connectionError =>
        'Impossible de joindre le serveur. Vérifie ta connexion.',
      DioExceptionType.badResponse =>
        'Le serveur a renvoyé une erreur (${e.response?.statusCode}).',
      _ => 'Erreur réseau inattendue.',
    };
  }
}
