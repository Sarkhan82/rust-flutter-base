import 'package:equatable/equatable.dart';

/// Hiérarchie typée des erreurs métier remontées à l'UI.
///
/// Un [Failure] ne porte **jamais** de texte destiné à l'écran : il porte une
/// **cause typée**. La traduction en message affichable se fait en couche
/// présentation via l'extension `FailureL10n`
/// (`core/l10n/failure_l10n.dart`) — le domaine et la data restent
/// i18n-agnostiques (cf. FLUTTER_ARCHITECTURE.md §2/§9).
///
/// Chaque couche convertit ses erreurs techniques (exceptions, erreurs HTTP…)
/// en un [Failure] à sa frontière. L'UI n'affiche jamais une exception brute.
sealed class Failure extends Equatable {
  const Failure();

  @override
  List<Object?> get props => [];
}

/// Cause d'un [NetworkFailure].
enum NetworkFailureKind {
  /// Timeout de connexion / envoi / réception.
  timeout,

  /// Connexion impossible (serveur down, DNS, pas de réseau).
  connection,

  /// Le serveur a répondu avec un status HTTP d'erreur (≥ 400).
  badResponse,

  /// Réponse reçue mais qui ne respecte pas le contrat d'API (parsing).
  malformedResponse,

  /// Erreur réseau non catégorisée.
  unexpected,
}

/// Échec de communication réseau avec le backend Rust.
final class NetworkFailure extends Failure {
  const NetworkFailure(this.kind, {this.statusCode});

  final NetworkFailureKind kind;

  /// Status HTTP si [kind] == [NetworkFailureKind.badResponse], sinon `null`.
  final int? statusCode;

  @override
  List<Object?> get props => [kind, statusCode];
}

/// Code de validation d'entrée (côté domaine). Ajouter un code par règle de
/// validation ; la traduction correspondante vit dans `FailureL10n` + ARB.
enum ValidationCode {
  /// L'input requis est vide (ou uniquement des espaces).
  emptyInput,
}

/// Donnée d'entrée invalide (validation côté domaine, avant tout I/O).
final class ValidationFailure extends Failure {
  const ValidationFailure(this.code);

  final ValidationCode code;

  @override
  List<Object?> get props => [code];
}

/// Erreur inattendue non catégorisée (filet de sécurité). Le détail technique
/// est loggé à la frontière qui l'a produit, jamais transporté ici.
final class UnexpectedFailure extends Failure {
  const UnexpectedFailure();
}
