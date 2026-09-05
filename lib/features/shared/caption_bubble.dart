import 'package:flutter/material.dart';
import 'package:humsukhan/core/l10n/app_strings.dart';
import 'package:humsukhan/core/theme/app_tokens.dart';
import 'package:humsukhan/domain/conversation/caption.dart';
import 'package:humsukhan/features/shared/badges.dart';
import 'package:humsukhan/features/shared/mixed_script_text.dart';

/// One caption, with a button that speaks it.
///
/// Whether *this* bubble is the one being spoken is decided by caption id, not
/// by comparing text: two identical captions must not both show the stop icon
/// (design.md §9).
class SpeakableCaptionBubble extends StatelessWidget {
  /// Creates a bubble.
  const SpeakableCaptionBubble({
    required this.caption,
    required this.strings,
    super.key,
    this.isSpeaking = false,
    this.onSpeak,
    this.onStopSpeaking,
    this.captionScale = 1.0,
    this.showLanguage = true,
  });

  /// What to show.
  final Caption caption;

  /// Localised copy.
  final AppStrings strings;

  /// Whether this exact caption is being spoken right now.
  final bool isSpeaking;

  /// Called to speak this caption. `null` disables the button.
  final VoidCallback? onSpeak;

  /// Called to stop speaking.
  final VoidCallback? onStopSpeaking;

  /// The caption-size multiplier.
  final double captionScale;

  /// Whether to show the detected language.
  final bool showLanguage;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool own = caption.speaker == CaptionSpeaker.own;
    final Color fill = own
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerHighest;
    final Color ink = own
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurface;
    final bool empty = caption.text.trim().isEmpty;

    return Align(
      alignment: own ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.86,
        ),
        margin: const EdgeInsets.only(bottom: AppTokens.spaceSm),
        padding: const EdgeInsets.all(AppTokens.spaceSm + 4),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  strings(
                    own
                        ? StringKey.everydayYouLabel
                        : StringKey.everydaySpeakerLabel,
                  ),
                  style: theme.textTheme.labelSmall?.copyWith(color: ink),
                ),
                const Spacer(),
                if (showLanguage)
                  LanguageBadge(language: caption.language, strings: strings),
              ],
            ),
            const SizedBox(height: AppTokens.spaceXs + 2),
            MixedScriptText(
              caption.text,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: ink,
                fontStyle: caption.isFinal
                    ? FontStyle.normal
                    : FontStyle.italic,
                fontWeight: caption.isFinal ? FontWeight.w500 : FontWeight.w400,
              ),
              scale: captionScale,
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Tooltip(
                message: strings(
                  isSpeaking
                      ? StringKey.everydayStopSpeaking
                      : StringKey.everydaySpeakThis,
                ),
                child: IconButton(
                  // Disabled when there is nothing to say, so the control never
                  // silently does nothing.
                  onPressed: empty
                      ? null
                      : (isSpeaking ? onStopSpeaking : onSpeak),
                  iconSize: 20,
                  constraints: const BoxConstraints(
                    minWidth: AppTokens.minHitTarget,
                    minHeight: AppTokens.minHitTarget,
                  ),
                  icon: Icon(
                    isSpeaking ? Icons.stop : Icons.volume_up_outlined,
                  ),
                  color: ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The live, uncommitted text, shown as the last bubble in the list.
class PartialCaptionBubble extends StatelessWidget {
  /// Creates a partial bubble.
  const PartialCaptionBubble({
    required this.text,
    required this.strings,
    super.key,
    this.captionScale = 1.0,
  });

  /// The unstable text.
  final String text;

  /// Localised copy.
  final AppStrings strings;

  /// The caption-size multiplier.
  final double captionScale;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.86,
        ),
        margin: const EdgeInsets.only(bottom: AppTokens.spaceSm),
        padding: const EdgeInsets.all(AppTokens.spaceSm + 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.6,
          ),
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: MixedScriptText(
          text,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontStyle: FontStyle.italic,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          scale: captionScale,
        ),
      ),
    );
  }
}
