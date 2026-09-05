import 'package:flutter/material.dart';
import 'package:humsukhan/core/l10n/app_strings.dart';
import 'package:humsukhan/core/theme/app_tokens.dart';
import 'package:humsukhan/domain/environment/sound_event.dart';
import 'package:humsukhan/domain/speech/language_policy.dart';

/// A small labelled pill.
class Pill extends StatelessWidget {
  /// Creates a pill.
  const Pill({
    required this.label,
    super.key,
    this.icon,
    this.background,
    this.foreground,
  });

  /// The text.
  final String label;

  /// An optional leading glyph.
  final IconData? icon;

  /// The fill.
  final Color? background;

  /// The text and icon colour.
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color fill = background ?? theme.colorScheme.secondaryContainer;
    final Color ink = foreground ?? theme.colorScheme.onSecondaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.spaceSm + 4,
        vertical: AppTokens.spaceXs + 2,
      ),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppTokens.radiusFull),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 14, color: ink),
            const SizedBox(width: AppTokens.spaceXs + 2),
          ],
          Text(label, style: theme.textTheme.labelSmall?.copyWith(color: ink)),
        ],
      ),
    );
  }
}

/// Shows what language a caption was classified as.
///
/// The classification is displayed, never silently corrected, and an internal
/// mode name such as `Auto` is never shown (design.md §9): mixed script reads
/// "English and Urdu".
class LanguageBadge extends StatelessWidget {
  /// Creates a badge.
  const LanguageBadge({
    required this.language,
    required this.strings,
    super.key,
  });

  /// What the caption was classified as.
  final CaptionLanguage language;

  /// Localised copy.
  final AppStrings strings;

  /// The user-facing name of [language].
  static StringKey labelKey(CaptionLanguage language) => switch (language) {
    CaptionLanguage.english => StringKey.langEnglish,
    CaptionLanguage.urdu => StringKey.langUrdu,
    CaptionLanguage.romanUrdu => StringKey.langRomanUrdu,
    CaptionLanguage.mixed => StringKey.langMixed,
    CaptionLanguage.undetermined => StringKey.langUndetermined,
  };

  @override
  Widget build(BuildContext context) =>
      Pill(label: strings(labelKey(language)), icon: Icons.translate);
}

/// Online or offline.
class ConnectivityBadge extends StatelessWidget {
  /// Creates a badge.
  const ConnectivityBadge({
    required this.online,
    required this.strings,
    super.key,
  });

  /// Whether the device has a connection.
  final bool online;

  /// Localised copy.
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Pill(
      label: strings(online ? StringKey.online : StringKey.offline),
      icon: online ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
      background: online
          ? theme.colorScheme.secondaryContainer
          : theme.colorScheme.errorContainer,
      foreground: online
          ? theme.colorScheme.onSecondaryContainer
          : theme.colorScheme.onErrorContainer,
    );
  }
}

/// Days until something deletes itself.
class RetentionBadge extends StatelessWidget {
  /// Creates a badge.
  const RetentionBadge({
    required this.daysRemaining,
    required this.strings,
    super.key,
  });

  /// Whole days left. Zero means today.
  final int daysRemaining;

  /// Localised copy.
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool soon = daysRemaining <= 1;
    final String label = switch (daysRemaining) {
      0 => strings(StringKey.proExpiresToday),
      1 => strings(StringKey.proExpiresTomorrow),
      _ => strings.format(StringKey.proExpiresInDays, <String, String>{
        'days': '$daysRemaining',
      }),
    };
    return Pill(
      label: label,
      icon: Icons.schedule,
      background: soon
          ? theme.colorScheme.errorContainer
          : theme.colorScheme.secondaryContainer,
      foreground: soon
          ? theme.colorScheme.onErrorContainer
          : theme.colorScheme.onSecondaryContainer,
    );
  }
}

/// How urgent a detected sound is.
class SeverityBadge extends StatelessWidget {
  /// Creates a badge.
  const SeverityBadge({
    required this.severity,
    required this.strings,
    super.key,
  });

  /// The urgency.
  final AlertSeverity severity;

  /// Localised copy.
  final AppStrings strings;

  /// The user-facing name of [severity].
  static StringKey labelKey(AlertSeverity severity) => switch (severity) {
    AlertSeverity.critical => StringKey.envSeverityCritical,
    AlertSeverity.high => StringKey.envSeverityHigh,
    AlertSeverity.normal => StringKey.envSeverityNormal,
  };

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final (Color fill, Color ink) = switch (severity) {
      AlertSeverity.critical => (
        theme.colorScheme.errorContainer,
        theme.colorScheme.onErrorContainer,
      ),
      AlertSeverity.high => (
        AppTokens.warning.withValues(alpha: 0.18),
        theme.colorScheme.onSurface,
      ),
      AlertSeverity.normal => (
        theme.colorScheme.secondaryContainer,
        theme.colorScheme.onSecondaryContainer,
      ),
    };
    return Pill(
      label: strings(labelKey(severity)),
      icon: severity == AlertSeverity.critical
          ? Icons.priority_high
          : Icons.notifications_active_outlined,
      background: fill,
      foreground: ink,
    );
  }
}

/// The user-facing name of a [SoundKind].
StringKey soundKindLabel(SoundKind kind) => switch (kind) {
  SoundKind.siren => StringKey.envSoundSiren,
  SoundKind.alarm => StringKey.envSoundAlarm,
  SoundKind.glassBreak => StringKey.envSoundGlassBreak,
  SoundKind.doorbell => StringKey.envSoundDoorbell,
  SoundKind.knock => StringKey.envSoundKnock,
  SoundKind.babyCry => StringKey.envSoundBabyCry,
  SoundKind.dogBark => StringKey.envSoundDogBark,
  SoundKind.vehicleHorn => StringKey.envSoundVehicleHorn,
  SoundKind.phone => StringKey.envSoundPhone,
};

/// The glyph shown for a [SoundKind].
IconData soundKindIcon(SoundKind kind) => switch (kind) {
  SoundKind.siren => Icons.emergency_outlined,
  SoundKind.alarm => Icons.alarm,
  SoundKind.glassBreak => Icons.broken_image_outlined,
  SoundKind.doorbell => Icons.doorbell_outlined,
  SoundKind.knock => Icons.sensor_door_outlined,
  SoundKind.babyCry => Icons.child_care_outlined,
  SoundKind.dogBark => Icons.pets_outlined,
  SoundKind.vehicleHorn => Icons.directions_car_outlined,
  SoundKind.phone => Icons.phone_in_talk_outlined,
};
