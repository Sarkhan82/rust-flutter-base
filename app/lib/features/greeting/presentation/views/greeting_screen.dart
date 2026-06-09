import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rust_flutter_base/features/greeting/presentation/view_models/greeting_view_model.dart';
import 'package:rust_flutter_base/l10n/generated/app_localizations.dart';

/// Écran témoin. Bind sur [greetingViewModelProvider], délègue toute logique au
/// ViewModel. Aucune logique métier ici.
class GreetingScreen extends ConsumerStatefulWidget {
  const GreetingScreen({super.key});

  @override
  ConsumerState<GreetingScreen> createState() => _GreetingScreenState();
}

class _GreetingScreenState extends ConsumerState<GreetingScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    ref.read(greetingViewModelProvider.notifier).greet(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(greetingViewModelProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.greetingTitle)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: l10n.greetingNameLabel,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: state is GreetingLoading ? null : _submit,
              child: Text(l10n.greetingSubmitButton),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: Center(
                child: _GreetingResult(
                  state: state,
                  idleHint: l10n.greetingIdleHint,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rend l'état courant. `switch` exhaustif garanti par la `sealed class`.
class _GreetingResult extends StatelessWidget {
  const _GreetingResult({required this.state, required this.idleHint});

  final GreetingState state;
  final String idleHint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return switch (state) {
      GreetingIdle() => Text(
          idleHint,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
      GreetingLoading() => const CircularProgressIndicator(),
      GreetingSuccess(:final greeting) => Text(
          greeting.message,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
      GreetingFailure(:final message) => Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium
              ?.copyWith(color: theme.colorScheme.error),
        ),
    };
  }
}
