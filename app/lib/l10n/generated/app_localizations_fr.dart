// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'package:rust_flutter_base/l10n/generated/app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Rust Flutter Base';

  @override
  String get greetingTitle => 'Salutation';

  @override
  String get greetingNameLabel => 'Votre nom';

  @override
  String get greetingSubmitButton => 'Saluer via Rust';

  @override
  String get greetingIdleHint =>
      'Saisissez un nom et appuyez sur le bouton. La salutation est calculée par le cœur Rust.';
}
