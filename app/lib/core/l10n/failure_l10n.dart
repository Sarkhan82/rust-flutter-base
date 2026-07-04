import 'package:rust_flutter_base/core/error/failure.dart';
import 'package:rust_flutter_base/l10n/generated/app_localizations.dart';

/// Traduction des [Failure] typés en messages affichables (présentation).
///
/// Pattern : domaine et data produisent des **causes typées** (aucune string
/// UI) ; c'est ici — et seulement ici — que la cause devient du texte, via les
/// ARB (cf. FLUTTER_ARCHITECTURE.md §2/§9). Les `switch` exhaustifs sur les
/// `sealed`/`enum` garantissent à la compilation qu'aucun nouveau `Failure`
/// ne peut arriver à l'écran sans traduction.
extension FailureL10n on Failure {
  /// Message localisé, prêt à afficher.
  String localizedMessage(AppLocalizations l10n) => switch (this) {
        NetworkFailure(:final kind, :final statusCode) => switch (kind) {
            NetworkFailureKind.timeout => l10n.errorNetworkTimeout,
            NetworkFailureKind.connection => l10n.errorNetworkConnection,
            NetworkFailureKind.badResponse =>
              l10n.errorNetworkBadResponse(statusCode ?? 0),
            NetworkFailureKind.malformedResponse =>
              l10n.errorNetworkMalformedResponse,
            NetworkFailureKind.unexpected => l10n.errorNetworkUnexpected,
          },
        ValidationFailure(:final code) => switch (code) {
            ValidationCode.emptyInput => l10n.errorValidationEmptyInput,
          },
        UnexpectedFailure() => l10n.errorUnexpected,
      };
}
