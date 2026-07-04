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

  @override
  String get errorNetworkTimeout => 'The server is taking too long to respond.';

  @override
  String get errorNetworkConnection =>
      'Unable to reach the server. Check your connection.';

  @override
  String errorNetworkBadResponse(int statusCode) {
    return 'The server returned an error ($statusCode).';
  }

  @override
  String get errorNetworkMalformedResponse =>
      'Unexpected response from the server. Try again later.';

  @override
  String get errorNetworkUnexpected => 'Unexpected network error.';

  @override
  String get errorValidationEmptyInput => 'This field cannot be empty.';

  @override
  String get errorUnexpected => 'Something went wrong. Try again later.';
}
