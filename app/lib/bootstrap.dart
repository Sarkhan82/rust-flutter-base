import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rust_flutter_base/app.dart';
import 'package:rust_flutter_base/core/config/app_config.dart';
import 'package:rust_flutter_base/core/di/providers.dart';
import 'package:rust_flutter_base/core/observability/logger.dart';

/// Point d'entrée commun à tous les flavors.
///
/// Centralise : capture globale des erreurs, override de la config par flavor,
/// init du pont Rust, montage du [ProviderScope].
Future<void> bootstrap(AppConfig config) async {
  WidgetsFlutterBinding.ensureInitialized();

  const logger = AppLogger();

  // Capture des erreurs framework + zone (brancher Sentry/Crashlytics ici).
  FlutterError.onError = (details) {
    logger.error('FlutterError', details.exception, details.stack);
  };

  await runZonedGuarded(
    () async {
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(config),
          // Pour brancher le vrai Rust : remplacer la ligne ci-dessous par
          //   rustBridgeProvider.overrideWithValue(FrbRustBridge()),
        ],
      );

      // Initialise le pont avant le premier frame.
      await container.read(rustBridgeProvider).init();

      runApp(
        UncontrolledProviderScope(
          container: container,
          child: const App(),
        ),
      );
    },
    (error, stack) => logger.error('Uncaught zone error', error, stack),
  );
}
