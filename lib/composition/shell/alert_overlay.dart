import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:humsukhan/application/providers.dart';
import 'package:humsukhan/core/l10n/app_strings.dart';
import 'package:humsukhan/core/theme/app_tokens.dart';
import 'package:humsukhan/domain/environment/sound_event.dart';
import 'package:humsukhan/domain/settings/app_settings.dart';
import 'package:humsukhan/features/shared/badges.dart';

/// Puts a detected sound in front of the user, wherever they are.
///
/// This is the visual half of a multi-channel alert. It is deliberately
/// unmissable and requires a tap to dismiss: a Deaf user cannot be told by a
/// sound, and a banner that fades on its own can be missed entirely.
class AlertOverlay extends ConsumerStatefulWidget {
  /// Wraps [child] with the alert surface.
  const AlertOverlay({required this.child, super.key});

  /// The app below the overlay.
  final Widget child;

  @override
  ConsumerState<AlertOverlay> createState() => _AlertOverlayState();
}

class _AlertOverlayState extends ConsumerState<AlertOverlay>
    with SingleTickerProviderStateMixin {
  StreamSubscription<SoundEvent>? _subscription;
  late final AnimationController _flash;
  SoundEvent? _current;

  @override
  void initState() {
    super.initState();
    _flash = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _subscription = ref
        .read(visualAlertsProvider)
        .stream
        .listen(
          _show,
          onError: (Object error, StackTrace stackTrace) {
            // Never empty: an alert channel that breaks is worth recording.
            debugPrint('visual alert stream error: $error');
          },
        );
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _flash.dispose();
    super.dispose();
  }

  void _show(SoundEvent event) {
    // Liveness check before touching state (B15).
    if (!mounted) return;
    setState(() => _current = event);
    final AlertChannels channels = ref.read(settingsProvider).alertChannels;
    if (channels.screenFlash) {
      unawaited(_flash.forward(from: 0).then((void _) => _flash.reverse()));
    }
  }

  void _dismiss() {
    if (!mounted) return;
    final SoundEvent? event = _current;
    setState(() => _current = null);
    if (event != null) {
      ref.read(monitoringProvider.notifier).controller.acknowledge(event);
    }
  }

  @override
  Widget build(BuildContext context) {
    final SoundEvent? event = _current;
    final AppStrings strings = ref.watch(stringsProvider);
    final ThemeData theme = Theme.of(context);

    return Stack(
      children: <Widget>[
        widget.child,
        // Screen flash: a full-surface pulse, for users who keep the phone in
        // view rather than in hand.
        IgnorePointer(
          child: FadeTransition(
            opacity: _flash,
            child: Container(
              color: theme.colorScheme.error.withValues(alpha: 0.5),
            ),
          ),
        ),
        if (event != null)
          Positioned(
            left: AppTokens.spaceMd,
            right: AppTokens.spaceMd,
            top: MediaQuery.paddingOf(context).top + AppTokens.spaceMd,
            child: Material(
              color: Colors.transparent,
              child: Semantics(
                liveRegion: true,
                label: strings(soundKindLabel(event.kind)),
                child: Container(
                  padding: const EdgeInsets.all(AppTokens.spaceMd),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                    border: Border.all(
                      color: theme.colorScheme.error,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        soundKindIcon(event.kind),
                        size: 32,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: AppTokens.spaceMd),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              strings(soundKindLabel(event.kind)),
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onErrorContainer,
                              ),
                            ),
                            const SizedBox(height: AppTokens.spaceXs),
                            SeverityBadge(
                              severity: event.severity,
                              strings: strings,
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: _dismiss,
                        child: Text(strings(StringKey.dismiss)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
