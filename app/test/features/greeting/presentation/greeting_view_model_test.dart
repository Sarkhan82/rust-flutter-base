import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rust_flutter_base/features/greeting/data/datasources/greeting_remote_data_source.dart';
import 'package:rust_flutter_base/features/greeting/greeting_providers.dart';
import 'package:rust_flutter_base/features/greeting/presentation/view_models/greeting_view_model.dart';

/// Fake contrôlable de la datasource HTTP (succès ou échec réseau).
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

ProviderContainer _containerWith(GreetingRemoteDataSource dataSource) {
  return ProviderContainer(
    overrides: [
      greetingRemoteDataSourceProvider.overrideWithValue(dataSource),
    ],
  );
}

void main() {
  test('état initial = GreetingIdle', () {
    final container = _containerWith(_FakeDataSource());
    addTearDown(container.dispose);

    expect(container.read(greetingViewModelProvider), isA<GreetingIdle>());
  });

  test('input valide → GreetingSuccess avec le message du backend', () async {
    final container = _containerWith(_FakeDataSource());
    addTearDown(container.dispose);

    await container.read(greetingViewModelProvider.notifier).greet('Ada');

    final state = container.read(greetingViewModelProvider);
    expect(state, isA<GreetingSuccess>());
    expect((state as GreetingSuccess).greeting.message, 'Hi Ada');
  });

  test('nom vide → GreetingFailure (validation)', () async {
    final container = _containerWith(_FakeDataSource());
    addTearDown(container.dispose);

    await container.read(greetingViewModelProvider.notifier).greet('   ');

    expect(container.read(greetingViewModelProvider), isA<GreetingFailure>());
  });

  test('échec réseau → GreetingFailure', () async {
    final container = _containerWith(_FakeDataSource(shouldThrow: true));
    addTearDown(container.dispose);

    await container.read(greetingViewModelProvider.notifier).greet('Ada');

    expect(container.read(greetingViewModelProvider), isA<GreetingFailure>());
  });
}
