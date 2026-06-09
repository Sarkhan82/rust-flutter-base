import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rust_flutter_base/core/di/providers.dart';
import 'package:rust_flutter_base/core/rust/rust_bridge.dart';
import 'package:rust_flutter_base/features/greeting/presentation/views/greeting_screen.dart';
import 'package:rust_flutter_base/l10n/generated/app_localizations.dart';

class _StubBridge implements RustBridge {
  @override
  Future<void> init() async {}
  @override
  Future<String> greet(String name) async => 'Hi $name';
}

Widget _wrap() => ProviderScope(
      overrides: [rustBridgeProvider.overrideWithValue(_StubBridge())],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: GreetingScreen(),
      ),
    );

void main() {
  testWidgets('saisie + tap → affiche la salutation calculée par Rust',
      (tester) async {
    await tester.pumpWidget(_wrap());

    await tester.enterText(find.byType(TextField), 'Ada');
    await tester.tap(find.byType(FilledButton));
    await tester.pump(); // Loading
    await tester.pumpAndSettle(); // Success

    expect(find.text('Hi Ada'), findsOneWidget);
  });
}
