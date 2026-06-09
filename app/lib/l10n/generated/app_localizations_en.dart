// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Rust Flutter Base';

  @override
  String get greetingTitle => 'Greeting';

  @override
  String get greetingNameLabel => 'Your name';

  @override
  String get greetingSubmitButton => 'Greet via Rust';

  @override
  String get greetingIdleHint =>
      'Enter a name and tap the button. The greeting is computed by the Rust core.';
}
