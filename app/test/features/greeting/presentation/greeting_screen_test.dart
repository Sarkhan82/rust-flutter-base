import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rust_flutter_base/features/greeting/data/datasources/greeting_remote_data_source.dart';
import 'package:rust_flutter_base/features/greeting/greeting_providers.dart';
import 'package:rust_flutter_base/features/greeting/presentation/views/greeting_screen.dart';
import 'package:rust_flutter_base/l10n/generated/app_localizations.dart';

/// Fake datasource : renvoie un message déterministe, zéro I/O réseau.
class _FakeDataSource implements GreetingRemoteDataSource {
  @override
  Future<String> fetchGreeting(String name) async => 'Hi $name';
}

Widget _wrap() => ProviderScope(
      overrides: [
        greetingRemoteDataSourceProvider.overrideWithValue(_FakeDataSource()),
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
}
