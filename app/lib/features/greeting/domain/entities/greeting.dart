import 'package:equatable/equatable.dart';

/// Entité métier : un message de salutation calculé par le cœur Rust.
///
/// Objet pur, sans dépendance framework/FFI. Immuable.
class Greeting extends Equatable {
  const Greeting({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}
