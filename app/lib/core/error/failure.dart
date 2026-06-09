import 'package:equatable/equatable.dart';

/// Hiérarchie typée des erreurs métier remontées à l'UI.
///
/// Chaque couche convertit ses erreurs techniques (exceptions, codes FFI…) en
/// un [Failure] à sa frontière. L'UI n'affiche jamais une exception brute.
sealed class Failure extends Equatable {
  const Failure(this.message);

  /// Message déjà prêt à être présenté (ou clé de traduction).
  final String message;

  @override
  List<Object?> get props => [message];
}

/// Échec de communication avec le cœur Rust / FFI.
final class RustFailure extends Failure {
  const RustFailure(super.message);
}

/// Donnée d'entrée invalide (validation côté domaine).
final class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

/// Erreur inattendue non catégorisée (filet de sécurité).
final class UnexpectedFailure extends Failure {
  const UnexpectedFailure(super.message);
}
