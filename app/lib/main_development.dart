import 'package:rust_flutter_base/bootstrap.dart';
import 'package:rust_flutter_base/core/config/app_config.dart';

/// Entrypoint flavor **development**.
/// `flutter run -t lib/main_development.dart`
void main() => bootstrap(AppConfig.development());
