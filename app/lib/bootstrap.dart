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
/// montage du [ProviderScope]. Le client HTTP (`dioProvider`) est paresseux :
/// il se construit à la première requête, pas besoin d'init au boot.
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
        ],
      );

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
