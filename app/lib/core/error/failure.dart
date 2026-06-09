import 'package:equatable/equatable.dart';

/// Hiérarchie typée des erreurs métier remontées à l'UI.
///
/// Chaque couche convertit ses erreurs techniques (exceptions, erreurs HTTP…)
/// en un [Failure] à sa frontière. L'UI n'affiche jamais une exception brute.
sealed class Failure extends Equatable {
  const Failure(this.message);

  /// Message déjà prêt à être présenté (ou clé de traduction).
  final String message;

  @override
  List<Object?> get props => [message];
}

/// Échec de communication réseau avec le backend Rust (timeout, connexion
/// refusée, status HTTP ≥ 400, réponse malformée).
final class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

/// Donnée d'entrée invalide (validation côté domaine).
final class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

/// Erreur inattendue non catégorisée (filet de sécurité).
final class UnexpectedFailure extends Failure {
  const UnexpectedFailure(super.message);
}
