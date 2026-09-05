import 'package:flutter/material.dart';
import 'package:humsukhan/core/l10n/app_strings.dart';
import 'package:humsukhan/core/theme/app_tokens.dart';

/// The zero state of a list or screen.
///
/// Distinct from [ErrorStateView]: an empty state must never stand in for a
/// failure (docs/instructions.md §4).
class EmptyStateView extends StatelessWidget {
  /// Creates an empty state.
  const EmptyStateView({
    required this.title,
    super.key,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  /// What is empty.
  final String title;

  /// What the user can do about it.
  final String? message;

  /// A glyph for the state.
  final IconData icon;

  /// An optional call to action.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: AppTokens.spaceMd),
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (message != null) ...<Widget>[
              const SizedBox(height: AppTokens.spaceSm),
              Text(
                message!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...<Widget>[
              const SizedBox(height: AppTokens.spaceLg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// A failure, with its reason and — when there is one — its remedy.
///
/// Never a bare spinner that stopped, and never an empty state.
class ErrorStateView extends StatelessWidget {
  /// Creates an error state.
  const ErrorStateView({
    required this.title,
    required this.message,
    super.key,
    this.remedy,
    this.onRetry,
    this.retryLabel,
  });

  /// A short heading.
  final String title;

  /// What happened.
  final String message;

  /// What the user can do.
  final String? remedy;

  /// Called when the user retries.
  final VoidCallback? onRetry;

  /// The retry button's label.
  final String? retryLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: AppTokens.spaceMd),
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTokens.spaceSm),
            Text(
              message,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (remedy != null) ...<Widget>[
              const SizedBox(height: AppTokens.spaceSm),
              Text(
                remedy!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (onRetry != null) ...<Widget>[
              const SizedBox(height: AppTokens.spaceLg),
              FilledButton(
                onPressed: onRetry,
                child: Text(retryLabel ?? 'Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A loading state that always says what it is waiting for.
class LoadingStateView extends StatelessWidget {
  /// Creates a loading state.
  const LoadingStateView({required this.message, super.key, this.onCancel});

  /// What is loading.
  final String message;

  /// Called when the user gives up. A spinner with no way out is forbidden
  /// (docs/instructions.md §4).
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const CircularProgressIndicator(),
            const SizedBox(height: AppTokens.spaceMd),
            Text(
              message,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (onCancel != null) ...<Widget>[
              const SizedBox(height: AppTokens.spaceMd),
              TextButton(onPressed: onCancel, child: const Text('Cancel')),
            ],
          ],
        ),
      ),
    );
  }
}

/// A section heading inside a screen.
class SectionHeader extends StatelessWidget {
  /// Creates a section header.
  const SectionHeader(this.title, {super.key, this.trailing});

  /// The heading text.
  final String title;

  /// An optional trailing action.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(
      top: AppTokens.spaceLg,
      bottom: AppTokens.spaceSm,
    ),
    child: Row(
      children: <Widget>[
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        ?trailing,
      ],
    ),
  );
}

/// The notice that travels with every piece of AI output.
class AiDisclaimer extends StatelessWidget {
  /// Creates a disclaimer.
  const AiDisclaimer({required this.strings, super.key});

  /// Localised copy.
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppTokens.spaceSm + 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.info_outline,
            size: 18,
            color: theme.colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: AppTokens.spaceSm),
          Expanded(
            child: Text(
              strings(StringKey.aiDisclaimer),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
