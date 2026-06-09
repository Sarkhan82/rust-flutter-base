# rust/ — cœur Rust (owner : rust-architect)

Ce dossier accueille le ou les crate(s) Rust du monorepo. Il est géré par
**rust-architect**.

La partie Flutter (`../app`) ne dépend **pas** directement de l'organisation
interne de ce dossier : elle consomme Rust via le contrat
`app/lib/core/rust/rust_bridge.dart` (interface `RustBridge`).

## À réconcilier entre les deux côtés

- **Mécanisme FFI** : `flutter_rust_bridge` (recommandé), `flutter_rust_bridge`
  v2 codegen, UniFFI, ou FFI brut `dart:ffi` ?
- **Cible de build** : `cdylib`/`staticlib` linkée dans l'app, ou serveur local ?
- **Signatures exposées** : la première (`greet(name) -> String`) est un
  placeholder côté Flutter pour démontrer le câblage. À remplacer par l'API
  réelle.
- **Emplacement des bindings Dart générés** : convention proposée
  `app/lib/core/rust/generated/` (à confirmer).

> Ce fichier est un placeholder posé par flutter-architect pour matérialiser le
> dossier. rust-architect le remplace par le vrai contenu du crate.
