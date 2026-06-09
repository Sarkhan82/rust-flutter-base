import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rust_flutter_base/core/config/app_config.dart';
import 'package:rust_flutter_base/core/observability/logger.dart';
import 'package:rust_flutter_base/core/rust/rust_bridge.dart';

/// Composition root des dépendances transverses.
///
/// Les providers spécifiques à une feature vivent dans la feature elle-même
/// (feature-first), pas ici.

/// Config de l'app. **Overridé au boot** par le flavor courant
/// (voir `bootstrap.dart`). Échoue volontairement si non overridé.
final appConfigProvider = Provider<AppConfig>(
  (ref) => throw UnimplementedError(
    'appConfigProvider doit être overridé dans bootstrap() avec le flavor.',
  ),
);

/// Logger applicatif.
final loggerProvider = Provider<AppLogger>((ref) => const AppLogger());

/// Pont vers le cœur Rust.
///
/// Défaut : [FakeRustBridge]. Pour brancher le vrai Rust, overrider ce provider
/// au boot avec l'implémentation basée sur les bindings FFI générés.
final rustBridgeProvider = Provider<RustBridge>(
  (ref) => const FakeRustBridge(),
);
