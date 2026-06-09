import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rust_flutter_base/core/di/providers.dart';
import 'package:rust_flutter_base/core/rust/rust_bridge.dart';

/// Service data : wrappe le [RustBridge] pour le besoin "greeting".
///
/// Un service = une source. Stateless. Il expose des appels bruts (peut lever
/// des exceptions) ; la conversion en `Result`/`Failure` est faite par le
/// repository.
class RustGreetingService {
  const RustGreetingService(this._bridge);

  final RustBridge _bridge;

  Future<String> greet(String name) => _bridge.greet(name);
}

final rustGreetingServiceProvider = Provider<RustGreetingService>(
  (ref) => RustGreetingService(ref.watch(rustBridgeProvider)),
);
