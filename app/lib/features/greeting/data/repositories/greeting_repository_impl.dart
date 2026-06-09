import 'package:rust_flutter_base/core/error/failure.dart';
import 'package:rust_flutter_base/core/error/result.dart';
import 'package:rust_flutter_base/features/greeting/data/services/rust_greeting_service.dart';
import 'package:rust_flutter_base/features/greeting/domain/entities/greeting.dart';
import 'package:rust_flutter_base/features/greeting/domain/repositories/greeting_repository.dart';

/// Implémentation du [GreetingRepository] (couche data).
///
/// Frontière I/O : c'est **ici** qu'on `try/catch` et qu'on convertit toute
/// exception technique en [Failure] typé. Aucune exception ne remonte au-delà.
class GreetingRepositoryImpl implements GreetingRepository {
  const GreetingRepositoryImpl(this._service);

  final RustGreetingService _service;

  @override
  Future<Result<Greeting>> fetchGreeting(String name) async {
    try {
      final message = await _service.greet(name);
      return Ok(Greeting(message: message));
    } on Exception catch (e) {
      return Err(RustFailure('Échec de l’appel au cœur Rust : $e'));
    }
  }
}
