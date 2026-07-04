import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Garde-fou d'architecture exécutable (cf. FLUTTER_ARCHITECTURE.md §1).
///
/// Vérifie mécaniquement la pureté des couches sur TOUTES les features — les
/// règles du CLAUDE.md ne restent pas de la prose : une violation fait échouer
/// `flutter test` (donc la CI). Complète l'analyse statique, qui ne connaît
/// pas nos frontières de couches.
///
/// Règles vérifiées :
/// - `domain/`  : Dart pur — zéro Flutter, Riverpod, Dio, go_router ; aucun
///   import des couches `data/` ou `presentation/`.
/// - `data/`    : zéro Flutter, Riverpod, go_router ; aucun import de
///   `presentation/`. (Dio y est légitime : c'est la frontière I/O.)
/// - `presentation/` : zéro Dio (aucun transport en UI) ; aucun import direct
///   de `data/` (le câblage passe par `<feature>_providers.dart`).
/// - `core/error/` : Dart pur (les Failure traversent le domaine).
void main() {
  group('pureté des couches (toutes features)', () {
    test('domain/ est du Dart pur, sans dépendance descendante', () {
      _expectNoImports(
        inDirs: _featureDirs('domain'),
        forbidden: [
          'package:flutter/',
          'package:flutter_riverpod/',
          'package:riverpod',
          'package:dio/',
          'package:go_router/',
          '/data/',
          '/presentation/',
        ],
      );
    });

    test("data/ n'importe ni Flutter, ni Riverpod, ni presentation/", () {
      _expectNoImports(
        inDirs: _featureDirs('data'),
        forbidden: [
          'package:flutter/',
          'package:flutter_riverpod/',
          'package:riverpod',
          'package:go_router/',
          '/presentation/',
        ],
      );
    });

    test("presentation/ n'importe ni Dio, ni data/ directement", () {
      _expectNoImports(
        inDirs: _featureDirs('presentation'),
        forbidden: [
          'package:dio/',
          '/data/',
        ],
      );
    });

    test('core/error/ est du Dart pur', () {
      _expectNoImports(
        inDirs: [Directory('lib/core/error')],
        forbidden: [
          'package:flutter/',
          'package:flutter_riverpod/',
          'package:dio/',
        ],
      );
    });
  });
}

/// Les sous-dossiers `<layer>` de chaque feature (`lib/features/*/<layer>`).
List<Directory> _featureDirs(String layer) {
  final features = Directory('lib/features');
  if (!features.existsSync()) return const [];
  return features
      .listSync()
      .whereType<Directory>()
      .map((f) => Directory('${f.path}/$layer'))
      .where((d) => d.existsSync())
      .toList();
}

/// Échoue si un fichier `.dart` de [inDirs] contient un import listé dans
/// [forbidden], avec le détail fichier + ligne pour corriger vite.
void _expectNoImports({
  required List<Directory> inDirs,
  required List<String> forbidden,
}) {
  final violations = <String>[];

  for (final dir in inDirs) {
    final dartFiles = dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));

    for (final file in dartFiles) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (!line.startsWith('import ') && !line.startsWith('export ')) {
          continue;
        }
        for (final pattern in forbidden) {
          if (line.contains(pattern)) {
            violations.add('${file.path}:${i + 1} → $line');
          }
        }
      }
    }
  }

  expect(
    violations,
    isEmpty,
    reason: 'Violation(s) de couche détectée(s) — cf. app/CLAUDE.md '
        '(Architecture) :\n${violations.join('\n')}',
  );
}
