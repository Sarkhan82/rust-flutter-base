import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rust_flutter_base/core/di/providers.dart';
import 'package:rust_flutter_base/features/greeting/data/repositories/greeting_repository_impl.dart';
import 'package:rust_flutter_base/features/greeting/data/services/rust_greeting_service.dart';
import 'package:rust_flutter_base/features/greeting/domain/repositories/greeting_repository.dart';
import 'package:rust_flutter_base/features/greeting/domain/usecases/get_greeting.dart';

/// Câblage Riverpod de la feature `greeting` (composition root local).
///
/// **Pourquoi un fichier dédié ?** Les classes des couches `domain/` et `data/`
/// restent du Dart pur : elles n'importent ni Riverpod ni une couche de plus
/// bas niveau. C'est ici — et seulement ici — qu'on assemble le graphe de
/// dépendances de la feature, en respectant le sens `presentation → domain →
/// data` (cf. FLUTTER_ARCHITECTURE.md, règle de dépendance).

/// Service data : wrappe le pont Rust transverse.
final rustGreetingServiceProvider = Provider<RustGreetingService>(
  (ref) => RustGreetingService(ref.watch(rustBridgeProvider)),
);

/// Implémentation concrète du repository (couche data).
final greetingRepositoryProvider = Provider<GreetingRepository>(
  (ref) => GreetingRepositoryImpl(ref.watch(rustGreetingServiceProvider)),
);

/// Cas d'usage exposé à la couche présentation.
final getGreetingProvider = Provider<GetGreeting>(
  (ref) => GetGreeting(ref.watch(greetingRepositoryProvider)),
);
