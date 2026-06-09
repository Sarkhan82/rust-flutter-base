import 'package:rust_flutter_base/bootstrap.dart';
import 'package:rust_flutter_base/core/config/app_config.dart';

/// Entrypoint flavor **staging**.
/// `flutter run -t lib/main_staging.dart`
void main() => bootstrap(AppConfig.staging());
