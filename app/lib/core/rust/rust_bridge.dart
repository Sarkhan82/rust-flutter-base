/// Contrat d'accès au cœur Rust.
///
/// **C'est l'unique point de couplage entre Flutter et Rust.** Aucune autre
/// couche n'importe les bindings FFI : elles dépendent de cette abstraction.
///
/// ## Aujourd'hui
/// [FakeRustBridge] est injecté (voir `core/di/providers.dart`) → l'app compile
/// et passe ses tests **sans** la partie Rust.
///
/// ## Demain (intégration du vrai cœur Rust)
/// 1. Générer les bindings (probablement via `flutter_rust_bridge`) dans
///    `lib/core/rust/generated/`.
/// 2. Créer `FrbRustBridge implements RustBridge` qui délègue aux fonctions
///    générées.
/// 3. Overrider `rustBridgeProvider` au boot avec cette impl.
///
/// Les signatures ci-dessous (`greet`) sont des **placeholders** démontrant le
/// câblage end-to-end ; à remplacer par l'API réelle convenue avec
/// rust-architect.
abstract interface class RustBridge {
  /// Initialise le pont (chargement de la lib native, handshake…).
  Future<void> init();

  /// Exemple d'appel vers Rust : renvoie un message de salutation.
  ///
  /// Lève une [Exception] en cas d'échec FFI ; la conversion en `Failure`
  /// typé est faite par la couche data.
  Future<String> greet(String name);
}

/// Implémentation factice — aucune dépendance native.
///
/// Sert tant que le cœur Rust n'est pas câblé, et de fake par défaut dans les
/// tests qui n'ont pas besoin d'un mock spécifique.
final class FakeRustBridge implements RustBridge {
  const FakeRustBridge();

  @override
  Future<void> init() async {}

  @override
  Future<String> greet(String name) async {
    // Simule la latence d'un appel FFI/async.
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return 'Bonjour, $name ! 👋 '
        '(réponse du pont factice — Rust pas encore câblé)';
  }
}
