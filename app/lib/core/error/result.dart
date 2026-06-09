import 'package:rust_flutter_base/core/error/failure.dart';

/// Type de retour des opérations faillibles.
///
/// `sealed` → le `switch` est exhaustif, le compilateur force le traitement des
/// deux branches. Aucune erreur ne peut être ignorée silencieusement.
///
/// ```dart
/// final result = await repository.fetch();
/// final widget = switch (result) {
///   Ok(:final value)  => Text(value.message),
///   Err(:final failure) => Text(failure.message),
/// };
/// ```
sealed class Result<T> {
  const Result();

  /// Construit un succès.
  const factory Result.ok(T value) = Ok<T>;

  /// Construit un échec.
  const factory Result.err(Failure failure) = Err<T>;

  /// `true` si succès.
  bool get isOk => this is Ok<T>;

  /// Valeur si succès, sinon `null`.
  T? get valueOrNull => switch (this) {
        Ok(:final value) => value,
        Err() => null,
      };

  /// Transforme la valeur de succès, propage l'échec.
  Result<R> map<R>(R Function(T value) transform) => switch (this) {
        Ok(:final value) => Ok(transform(value)),
        Err(:final failure) => Err(failure),
      };
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.failure);
  final Failure failure;
}
