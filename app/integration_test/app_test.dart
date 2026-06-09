import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rust_flutter_base/app.dart';
import 'package:rust_flutter_base/core/config/app_config.dart';
import 'package:rust_flutter_base/core/di/providers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('parcours greeting de bout en bout (pont factice)',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(AppConfig.development()),
        ],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Ada');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    // Le pont factice renvoie un message contenant le nom saisi.
    expect(find.textContaining('Ada'), findsOneWidget);
  });
}
