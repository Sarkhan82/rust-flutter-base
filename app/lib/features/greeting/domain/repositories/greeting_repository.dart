import 'package:rust_flutter_base/core/error/result.dart';
import 'package:rust_flutter_base/features/greeting/domain/entities/greeting.dart';

/// Contrat d'accès aux salutations (interface, couche domaine).
///
/// L'implémentation vit dans `data/` (inversion de dépendance) : le domaine ne
/// connaît ni Rust, ni FFI, ni service.
abstract interface class GreetingRepository {
  Future<Result<Greeting>> fetchGreeting(String name);
}
