import 'dart:developer' as developer;

/// Logger minimal sans dépendance (remplace `print`, banni par les lints).
///
/// En production, brancher ici un vrai backend (Sentry / Crashlytics) — voir
/// FLUTTER_ARCHITECTURE.md §12. Garder une interface pour rester testable.
class AppLogger {
  const AppLogger();

  void info(String message) => developer.log(message, name: 'INFO');

  void warn(String message) => developer.log(message, name: 'WARN');

  void error(String message, [Object? error, StackTrace? stackTrace]) {
    developer.log(
      message,
      name: 'ERROR',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
