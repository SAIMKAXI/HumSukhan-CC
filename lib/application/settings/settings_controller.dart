import 'dart:async';

import 'package:humsukhan/application/common/async_state.dart';
import 'package:humsukhan/core/failure/failure.dart';
import 'package:humsukhan/core/l10n/app_language.dart';
import 'package:humsukhan/core/result/result.dart';
import 'package:humsukhan/domain/conversation/conversation_repository_port.dart';
import 'package:humsukhan/domain/conversation/turn_policy.dart';
import 'package:humsukhan/domain/professional/retention_policy.dart';
import 'package:humsukhan/domain/settings/app_settings.dart';
import 'package:humsukhan/domain/settings/settings_port.dart';
import 'package:humsukhan/domain/speech/language_tag.dart';

/// Loads, holds and persists the user's choices.
///
/// Every mutation writes through and reports the outcome; a setting that
/// appears to change and does not persist is a silent failure.
final class SettingsController {
  /// Creates a controller over [port].
  SettingsController({required SettingsPort port}) : _port = port;

  final SettingsPort _port;

  final StreamController<AsyncState<AppSettings>> _states =
      StreamController<AsyncState<AppSettings>>.broadcast();

  AsyncState<AppSettings> _state = const AsyncIdle<AppSettings>();
  bool _disposed = false;

  /// The load state right now.
  AsyncState<AppSettings> get state => _state;

  /// Every change to [state].
  Stream<AsyncState<AppSettings>> get states => _states.stream;

  /// The settings in force, falling back to defaults before the load finishes.
  AppSettings get settings => _state.valueOrNull ?? const AppSettings();

  /// Loads the stored settings.
  Future<void> load() async {
    if (_disposed) return;
    _emit(const AsyncLoading<AppSettings>());
    final Result<AppSettings, StorageFailure> result = await _port.load();
    if (_disposed) return;
    _emit(
      result.fold(AsyncSuccess<AppSettings>.new, AsyncFailure<AppSettings>.new),
    );
  }

  /// Applies [next] and persists it.
  Future<Result<Unit, StorageFailure>> update(AppSettings next) async {
    if (_disposed) {
      return const Err<Unit, StorageFailure>(
        StorageFailure(FailureCode.storageWriteFailed, isRecoverable: false),
      );
    }
    // Optimistic: the UI reflects the choice immediately, and a write failure
    // surfaces rather than silently reverting.
    _emit(AsyncSuccess<AppSettings>(next));
    return _port.save(next);
  }

  /// Sets the interface language.
  Future<Result<Unit, StorageFailure>> setAppLanguage(AppLanguage language) =>
      update(settings.copyWith(appLanguage: language));

  /// Sets the recognition language.
  Future<Result<Unit, StorageFailure>> setCaptionLanguage(LanguageTag tag) =>
      update(settings.copyWith(captionLanguage: tag));

  /// Turns the dark theme on or off.
  Future<Result<Unit, StorageFailure>> setDarkMode(bool value) =>
      update(settings.copyWith(darkMode: value));

  /// Turns the high-contrast theme on or off.
  Future<Result<Unit, StorageFailure>> setHighContrast(bool value) =>
      update(settings.copyWith(highContrast: value));

  /// Turns the large-text multiplier on or off.
  Future<Result<Unit, StorageFailure>> setLargeText(bool value) =>
      update(settings.copyWith(largeText: value));

  /// Sets the caption size multiplier.
  Future<Result<Unit, StorageFailure>> setCaptionScale(double value) =>
      update(settings.copyWith(captionScale: value));

  /// Sets the pause rule.
  Future<Result<Unit, StorageFailure>> setPauseThreshold(
    PauseThreshold threshold,
  ) => update(settings.copyWith(pauseThreshold: threshold));

  /// Sets how long material is kept, clamped to the product maximum.
  Future<Result<Unit, StorageFailure>> setRetentionDays(int days) =>
      update(settings.copyWith(retentionDays: RetentionPolicy(days).days));

  /// Sets which alert channels are used.
  Future<Result<Unit, StorageFailure>> setAlertChannels(
    AlertChannels channels,
  ) => update(settings.copyWith(alertChannels: channels));

  /// Records that onboarding finished.
  Future<Result<Unit, StorageFailure>> completeOnboarding() =>
      update(settings.copyWith(onboardingComplete: true));

  /// Records whether monitoring should resume on launch.
  Future<Result<Unit, StorageFailure>> setMonitoringEnabled(bool value) =>
      update(settings.copyWith(monitoringEnabled: value));

  /// Stops emitting.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _states.close();
  }

  void _emit(AsyncState<AppSettings> next) {
    if (_disposed) return;
    _state = next;
    if (!_states.isClosed) _states.add(next);
  }
}
