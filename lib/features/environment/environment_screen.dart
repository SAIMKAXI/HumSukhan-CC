import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:humsukhan/application/environment/monitoring_controller.dart';
import 'package:humsukhan/application/providers.dart';
import 'package:humsukhan/core/l10n/app_strings.dart';
import 'package:humsukhan/core/theme/app_tokens.dart';
import 'package:humsukhan/domain/environment/model_state.dart';
import 'package:humsukhan/domain/environment/sound_event.dart';
import 'package:humsukhan/features/shared/badges.dart';
import 'package:humsukhan/features/shared/state_views.dart';

/// Environmental monitoring: the toggle, what it listens for, and what it heard.
class EnvironmentScreen extends ConsumerWidget {
  /// Creates the screen.
  const EnvironmentScreen({super.key});

  /// Toggles monitoring, persisting the choice so it survives a restart and so
  /// the Quick Settings tile can show the same state.
  static Future<void> toggle(WidgetRef ref, {required bool on}) =>
      _toggle(ref, on);

  static Future<void> _toggle(WidgetRef ref, bool on) async {
    await ref
        .read(settingsControllerProvider.notifier)
        .controller
        .setMonitoringEnabled(on);
    // Read the controller *after* the write, never before: holding a reference
    // across an await is how a command ends up talking to an object the
    // container has already replaced.
    final MonitoringController controller = ref
        .read(monitoringProvider.notifier)
        .controller;
    if (on) {
      final AppStrings strings = ref.read(stringsProvider);
      // The failure is rendered by the banner below; nothing is swallowed.
      await controller.start(
        notificationTitle: strings(StringKey.envNotificationTitle),
        notificationBody: strings(StringKey.envNotificationBody),
      );
    } else {
      await controller.stop();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MonitoringState state = ref.watch(monitoringProvider);
    final AppStrings strings = ref.watch(stringsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(strings(StringKey.envTitle))),
      body: ListView(
        padding: const EdgeInsets.all(AppTokens.spaceMd),
        children: <Widget>[
          _StateBanner(state: state, strings: strings),
          const SizedBox(height: AppTokens.spaceMd),
          Card(
            child: SwitchListTile(
              value: state.isRunning,
              onChanged: (bool value) => unawaited(_toggle(ref, value)),
              title: Text(strings(StringKey.envMonitoring)),
              subtitle: Text(strings(StringKey.envForegroundNotice)),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppTokens.spaceMd,
                vertical: AppTokens.spaceSm,
              ),
            ),
          ),
          const SizedBox(height: AppTokens.spaceMd),
          _PrivacyStrip(strings: strings),
          SectionHeader(strings(StringKey.envSupportedSounds)),
          Wrap(
            spacing: AppTokens.spaceSm,
            runSpacing: AppTokens.spaceSm,
            children: SoundKind.values
                .map(
                  (SoundKind kind) => Pill(
                    label: strings(soundKindLabel(kind)),
                    icon: soundKindIcon(kind),
                  ),
                )
                .toList(growable: false),
          ),
          SectionHeader(
            strings(StringKey.envHistory),
            trailing: state.events.isEmpty
                ? null
                : TextButton(
                    onPressed: () => ref
                        .read(monitoringProvider.notifier)
                        .controller
                        .clearHistory(),
                    child: Text(strings(StringKey.envClearHistory)),
                  ),
          ),
          if (state.events.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppTokens.spaceLg),
              child: EmptyStateView(
                title: strings(StringKey.envNoAlerts),
                icon: Icons.notifications_none,
              ),
            )
          else
            ...state.events.map(
              (SoundEvent event) => _AlertCard(
                key: ValueKey<String>(event.id),
                event: event,
                strings: strings,
                onAcknowledge: () => ref
                    .read(monitoringProvider.notifier)
                    .controller
                    .acknowledge(event),
              ),
            ),
        ],
      ),
    );
  }
}

class _StateBanner extends ConsumerWidget {
  const _StateBanner({required this.state, required this.strings});

  final MonitoringState state;
  final AppStrings strings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);

    // Every phase is a named, visible state with its own reason and remedy.
    final (
      Color fill,
      Color ink,
      IconData icon,
      String title,
      String? detail,
    ) = switch (state.phase) {
      MonitoringPhase.off => (
        theme.colorScheme.surfaceContainerHighest,
        theme.colorScheme.onSurface,
        Icons.notifications_off_outlined,
        strings(StringKey.envStateOff),
        _modelDetail(strings, state.model),
      ),
      MonitoringPhase.starting => (
        theme.colorScheme.secondaryContainer,
        theme.colorScheme.onSecondaryContainer,
        Icons.hourglass_empty,
        strings(StringKey.envStateStarting),
        _modelDetail(strings, state.model),
      ),
      MonitoringPhase.active => (
        theme.colorScheme.primaryContainer,
        theme.colorScheme.onPrimaryContainer,
        Icons.hearing,
        strings(StringKey.envStateActive),
        null,
      ),
      MonitoringPhase.failed => (
        theme.colorScheme.errorContainer,
        theme.colorScheme.onErrorContainer,
        Icons.error_outline,
        strings(StringKey.envStateFailed),
        state.failure == null ? null : strings.describe(state.failure!),
      ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTokens.spaceMd),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Semantics(
        liveRegion: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: ink),
            const SizedBox(width: AppTokens.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(color: ink),
                  ),
                  if (detail != null) ...<Widget>[
                    const SizedBox(height: AppTokens.spaceXs),
                    Text(
                      detail,
                      style: theme.textTheme.bodySmall?.copyWith(color: ink),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _modelDetail(AppStrings strings, ModelState model) => switch (model) {
    ModelReady() => strings(StringKey.envModelReady),
    ModelVerifying() => strings(StringKey.envModelVerifying),
    ModelDownloading() => strings(StringKey.envModelDownloading),
    ModelAbsent() => strings(StringKey.envModelAbsent),
    ModelFailed(:final ModelFailure cause) => strings.describe(cause),
  };
}

class _PrivacyStrip extends StatelessWidget {
  const _PrivacyStrip({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Icon(
          Icons.phonelink_lock_outlined,
          size: 18,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppTokens.spaceSm),
        Expanded(
          child: Text(
            strings(StringKey.envOnDeviceNotice),
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({
    required this.event,
    required this.strings,
    required this.onAcknowledge,
    super.key,
  });

  final SoundEvent event;
  final AppStrings strings;
  final VoidCallback onAcknowledge;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String time =
        '${event.detectedAt.hour.toString().padLeft(2, '0')}:'
        '${event.detectedAt.minute.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.only(bottom: AppTokens.spaceSm),
      // A Row, not a ListTile: the badges make this taller than a tile is
      // designed for, and a ListTile lays its trailing control outside those
      // bounds — leaving a dismiss button that draws and cannot be tapped.
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceMd),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              soundKindIcon(event.kind),
              size: 32,
              color: event.acknowledged
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.error,
            ),
            const SizedBox(width: AppTokens.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    strings(soundKindLabel(event.kind)),
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppTokens.spaceSm),
                  Wrap(
                    spacing: AppTokens.spaceSm,
                    runSpacing: AppTokens.spaceXs,
                    children: <Widget>[
                      SeverityBadge(severity: event.severity, strings: strings),
                      Pill(
                        label: strings.format(
                          StringKey.envDetectedAt,
                          <String, String>{'time': time},
                        ),
                        icon: Icons.schedule,
                      ),
                      Pill(
                        label: strings.format(
                          StringKey.envConfidence,
                          <String, String>{
                            'percent': '${(event.confidence * 100).round()}',
                          },
                        ),
                        icon: Icons.insights_outlined,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppTokens.spaceSm),
            if (event.acknowledged)
              Icon(Icons.check, color: theme.colorScheme.onSurfaceVariant)
            else
              IconButton(
                tooltip: strings(StringKey.dismiss),
                onPressed: onAcknowledge,
                icon: const Icon(Icons.close),
              ),
          ],
        ),
      ),
    );
  }
}
