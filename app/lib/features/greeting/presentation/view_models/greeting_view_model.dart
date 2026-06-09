import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rust_flutter_base/core/error/result.dart';
import 'package:rust_flutter_base/features/greeting/domain/entities/greeting.dart';
import 'package:rust_flutter_base/features/greeting/domain/usecases/get_greeting.dart';

/// État immuable de l'écran greeting. `sealed` → `switch` exhaustif dans l'UI.
sealed class GreetingState extends Equatable {
  const GreetingState();

  @override
  List<Object?> get props => [];
}

final class GreetingIdle extends GreetingState {
  const GreetingIdle();
}

final class GreetingLoading extends GreetingState {
  const GreetingLoading();
}

final class GreetingSuccess extends GreetingState {
  const GreetingSuccess(this.greeting);
  final Greeting greeting;

  @override
  List<Object?> get props => [greeting];
}

final class GreetingFailure extends GreetingState {
  const GreetingFailure(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}

/// ViewModel : transforme l'action utilisateur en états affichables.
/// Zéro widget, zéro `BuildContext` → testable en pur Dart.
class GreetingViewModel extends Notifier<GreetingState> {
  @override
  GreetingState build() => const GreetingIdle();

  Future<void> greet(String name) async {
    state = const GreetingLoading();
    final result = await ref.read(getGreetingProvider).call(name);
    state = switch (result) {
      Ok(:final value) => GreetingSuccess(value),
      Err(:final failure) => GreetingFailure(failure.message),
    };
  }
}

final greetingViewModelProvider =
    NotifierProvider<GreetingViewModel, GreetingState>(GreetingViewModel.new);
