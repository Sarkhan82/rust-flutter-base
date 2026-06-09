import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:rust_flutter_base/features/greeting/presentation/views/greeting_screen.dart';

/// Noms de routes centralisés (évite les chaînes magiques dispersées).
abstract final class Routes {
  static const greeting = '/';
}

/// Routeur déclaratif exposé en provider (testable, overridable).
///
/// Ajouter les guards d'auth via `redirect` quand une feature auth existe
/// (cf. FLUTTER_ARCHITECTURE.md §8).
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: Routes.greeting,
    routes: [
      GoRoute(
        path: Routes.greeting,
        builder: (context, state) => const GreetingScreen(),
      ),
    ],
  );
});
