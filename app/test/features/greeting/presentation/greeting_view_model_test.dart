import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rust_flutter_base/core/di/providers.dart';
import 'package:rust_flutter_base/core/rust/rust_bridge.dart';
import 'package:rust_flutter_base/features/greeting/presentation/view_models/greeting_view_model.dart';

/// Stub contrôlable du pont Rust (succès ou échec FFI).
class _StubBridge implements RustBridge {
  _StubBridge({this.shouldThrow = false});
  final bool shouldThrow;

  @override
  Future<void> init() async {}

  @override
  Future<String> greet(String name) async {
    if (shouldThrow) throw Exception('ffi error');
    return 'Hi $name';
  }
}

ProviderContainer _containerWith(RustBridge bridge) {
  return ProviderContainer(
    overrides: [rustBridgeProvider.overrideWithValue(bridge)],
  );
}

void main() {
  test('état initial = GreetingIdle', () {
    final container = _containerWith(_StubBridge());
    addTearDown(container.dispose);

    expect(container.read(greetingViewModelProvider), isA<GreetingIdle>());
  });

  test('input valide → GreetingSuccess avec le message de Rust', () async {
    final container = _containerWith(_StubBridge());
    addTearDown(container.dispose);

    await container.read(greetingViewModelProvider.notifier).greet('Ada');

    final state = container.read(greetingViewModelProvider);
    expect(state, isA<GreetingSuccess>());
    expect((state as GreetingSuccess).greeting.message, 'Hi Ada');
  });

  test('nom vide → GreetingFailure (validation)', () async {
    final container = _containerWith(_StubBridge());
    addTearDown(container.dispose);

    await container.read(greetingViewModelProvider.notifier).greet('   ');

    expect(container.read(greetingViewModelProvider), isA<GreetingFailure>());
  });

  test('échec FFI → GreetingFailure', () async {
    final container = _containerWith(_StubBridge(shouldThrow: true));
    addTearDown(container.dispose);

    await container.read(greetingViewModelProvider.notifier).greet('Ada');

    expect(container.read(greetingViewModelProvider), isA<GreetingFailure>());
  });
}
