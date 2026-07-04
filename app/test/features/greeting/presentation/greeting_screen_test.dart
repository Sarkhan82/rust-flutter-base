import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rust_flutter_base/features/greeting/data/datasources/greeting_remote_data_source.dart';
import 'package:rust_flutter_base/features/greeting/greeting_providers.dart';
import 'package:rust_flutter_base/features/greeting/presentation/views/greeting_screen.dart';
import 'package:rust_flutter_base/l10n/generated/app_localizations.dart';

/// Fake datasource : réponse déterministe (succès ou échec réseau), zéro I/O.
class _FakeDataSource implements GreetingRemoteDataSource {
  _FakeDataSource({this.shouldThrow = false});
  final bool shouldThrow;

  @override
  Future<String> fetchGreeting(String name) async {
    if (shouldThrow) {
      throw DioException.connectionError(
        requestOptions: RequestOptions(path: '/api/v1/greeting'),
        reason: 'connection refused',
      );
    }
    return 'Hi $name';
  }
}

Widget _wrap({bool shouldThrow = false}) => ProviderScope(
      overrides: [
        greetingRemoteDataSourceProvider
            .overrideWithValue(_FakeDataSource(shouldThrow: shouldThrow)),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: GreetingScreen(),
      ),
    );

void main() {
  testWidgets('saisie + tap → affiche la salutation renvoyée par le backend',
      (tester) async {
    await tester.pumpWidget(_wrap());

    await tester.enterText(find.byType(TextField), 'Ada');
    await tester.tap(find.byType(FilledButton));
    await tester.pump(); // Loading
    await tester.pumpAndSettle(); // Success

    expect(find.text('Hi Ada'), findsOneWidget);
  });

  testWidgets(
      'échec réseau → message localisé (mapping Failure → l10n), '
      "aucun détail technique à l'écran", (tester) async {
    await tester.pumpWidget(_wrap(shouldThrow: true));

    await tester.enterText(find.byType(TextField), 'Ada');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    // Locale par défaut des widget tests = en → clé errorNetworkConnection.
    expect(
      find.text('Unable to reach the server. Check your connection.'),
      findsOneWidget,
    );
    // Le détail technique ne fuit jamais à l'écran (cf. §2/§10).
    expect(find.textContaining('connection refused'), findsNothing);
    expect(find.textContaining('DioException'), findsNothing);
  });
}
