import 'package:rust_flutter_base/bootstrap.dart';
import 'package:rust_flutter_base/core/config/app_config.dart';

/// Entrypoint flavor **production**.
/// `flutter run -t lib/main_production.dart --release`
void main() => bootstrap(AppConfig.production());
