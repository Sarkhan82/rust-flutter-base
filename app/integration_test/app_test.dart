import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rust_flutter_base/app.dart';
import 'package:rust_flutter_base/core/config/app_config.dart';
import 'package:rust_flutter_base/core/di/providers.dart';
import 'package:rust_flutter_base/features/greeting/data/datasources/greeting_remote_data_source.dart';
import 'package:rust_flutter_base/features/greeting/greeting_providers.dart';

/// Datasource factice : évite tout appel réseau réel pendant l'E2E. Renvoie un
/// message contenant le nom saisi, comme le ferait le backend Rust.
class _FakeDataSource implements GreetingRemoteDataSource {
  @override
  Future<String> fetchGreeting(String name) async => 'Bonjour, $name ! 👋';
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('parcours greeting de bout en bout (datasource factice)',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(AppConfig.development()),
          greetingRemoteDataSourceProvider.overrideWithValue(_FakeDataSource()),
        ],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Ada');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    // La datasource factice renvoie un message contenant le nom saisi.
    expect(find.textContaining('Ada'), findsOneWidget);
  });
}
