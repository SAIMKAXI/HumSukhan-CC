import 'package:humsukhan/core/l10n/app_language.dart';
import 'package:humsukhan/domain/conversation/turn_policy.dart';
import 'package:humsukhan/domain/professional/retention_policy.dart';
import 'package:humsukhan/domain/speech/language_tag.dart';

/// How the user wants to be alerted to a sound they cannot hear.
///
/// More than one may be on at once; a Deaf user must never depend on a single
/// channel (design.md §7).
final class AlertChannels {
  /// Creates a channel selection.
  const AlertChannels({
    this.haptic = true,
    this.visual = true,
    this.torch = false,
    this.screenFlash = true,
  });

  /// Vibrate.
  final bool haptic;

  /// Show a banner or dialog.
  final bool visual;

  /// Pulse the camera flash.
  final bool torch;

  /// Flash the screen.
  final bool screenFlash;

  /// Whether at least one channel is on. A selection with none is a silent,
  /// invisible alert — the UI refuses to leave the user there.
  bool get hasAny => haptic || visual || torch || screenFlash;

  /// A copy with the given fields replaced.
  AlertChannels copyWith({
    bool? haptic,
    bool? visual,
    bool? torch,
    bool? screenFlash,
  }) => AlertChannels(
    haptic: haptic ?? this.haptic,
    visual: visual ?? this.visual,
    torch: torch ?? this.torch,
    screenFlash: screenFlash ?? this.screenFlash,
  );

  @override
  bool operator ==(Object other) =>
      other is AlertChannels &&
      other.haptic == haptic &&
      other.visual == visual &&
      other.torch == torch &&
      other.screenFlash == screenFlash;

  @override
  int get hashCode => Object.hash(haptic, visual, torch, screenFlash);
}

/// Everything the user has chosen.
final class AppSettings {
  /// Creates a settings snapshot.
  const AppSettings({
    this.appLanguage = AppLanguage.english,
    this.captionLanguage = LanguageTag.english,
    this.darkMode = false,
    this.highContrast = false,
    this.largeText = false,
    this.captionScale = 1,
    this.pauseThreshold = PauseThreshold.natural,
    this.retentionDays = 7,
    this.alertChannels = const AlertChannels(),
    this.onboardingComplete = false,
    this.monitoringEnabled = false,
  });

  /// The language of the interface.
  final AppLanguage appLanguage;

  /// The language captions are recognised in.
  final LanguageTag captionLanguage;

  /// Whether the dark theme is selected.
  final bool darkMode;

  /// Whether the high-contrast theme is selected. Takes precedence over
  /// [darkMode] — it is a separate theme, not a modifier.
  final bool highContrast;

  /// Whether to multiply the OS text scale by 1.2.
  final bool largeText;

  /// Caption text multiplier, independent of app text size.
  final double captionScale;

  /// How long a pause commits an utterance.
  final PauseThreshold pauseThreshold;

  /// How long saved material is kept.
  final int retentionDays;

  /// How alerts reach the user.
  final AlertChannels alertChannels;

  /// Whether onboarding has been completed.
  final bool onboardingComplete;

  /// Whether environmental monitoring should resume.
  final bool monitoringEnabled;

  /// The multiplier applied on top of the platform text scale.
  ///
  /// Multiplies, never replaces: the user's OS setting is respected
  /// (design.md §7).
  double get textScaleMultiplier => largeText ? 1.2 : 1;

  /// The retention rule these settings imply.
  RetentionPolicy get retention => RetentionPolicy(retentionDays);

  /// A copy with the given fields replaced.
  AppSettings copyWith({
    AppLanguage? appLanguage,
    LanguageTag? captionLanguage,
    bool? darkMode,
    bool? highContrast,
    bool? largeText,
    double? captionScale,
    PauseThreshold? pauseThreshold,
    int? retentionDays,
    AlertChannels? alertChannels,
    bool? onboardingComplete,
    bool? monitoringEnabled,
  }) => AppSettings(
    appLanguage: appLanguage ?? this.appLanguage,
    captionLanguage: captionLanguage ?? this.captionLanguage,
    darkMode: darkMode ?? this.darkMode,
    highContrast: highContrast ?? this.highContrast,
    largeText: largeText ?? this.largeText,
    captionScale: captionScale ?? this.captionScale,
    pauseThreshold: pauseThreshold ?? this.pauseThreshold,
    retentionDays: retentionDays ?? this.retentionDays,
    alertChannels: alertChannels ?? this.alertChannels,
    onboardingComplete: onboardingComplete ?? this.onboardingComplete,
    monitoringEnabled: monitoringEnabled ?? this.monitoringEnabled,
  );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.appLanguage == appLanguage &&
      other.captionLanguage == captionLanguage &&
      other.darkMode == darkMode &&
      other.highContrast == highContrast &&
      other.largeText == largeText &&
      other.captionScale == captionScale &&
      other.pauseThreshold == pauseThreshold &&
      other.retentionDays == retentionDays &&
      other.alertChannels == alertChannels &&
      other.onboardingComplete == onboardingComplete &&
      other.monitoringEnabled == monitoringEnabled;

  @override
  int get hashCode => Object.hash(
    appLanguage,
    captionLanguage,
    darkMode,
    highContrast,
    largeText,
    captionScale,
    pauseThreshold,
    retentionDays,
    alertChannels,
    onboardingComplete,
    monitoringEnabled,
  );
}
