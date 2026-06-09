import 'package:rust_flutter_base/core/error/failure.dart';
import 'package:rust_flutter_base/core/error/result.dart';
import 'package:rust_flutter_base/features/greeting/domain/entities/greeting.dart';
import 'package:rust_flutter_base/features/greeting/domain/repositories/greeting_repository.dart';

/// Cas d'usage : obtenir une salutation pour un nom donné.
///
/// Porte une vraie logique métier (validation de l'input) → ce n'est pas un
/// pass-through (cf. règle anti-over-engineering, FLUTTER_ARCHITECTURE.md §14).
///
/// **Dart pur** : aucune dépendance framework (pas de Riverpod). Le provider
/// qui l'instancie vit dans `features/greeting/greeting_providers.dart`.
class GetGreeting {
  const GetGreeting(this._repository);

  final GreetingRepository _repository;

  Future<Result<Greeting>> call(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return Future.value(
        const Err(ValidationFailure('Le nom ne peut pas être vide.')),
      );
    }
    return _repository.fetchGreeting(trimmed);
  }
}
