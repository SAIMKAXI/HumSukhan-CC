import 'dart:convert';

import 'package:humsukhan/core/failure/failure.dart';
import 'package:humsukhan/core/l10n/app_language.dart';
import 'package:humsukhan/core/logging/app_logger.dart';
import 'package:humsukhan/core/result/result.dart';
import 'package:humsukhan/domain/conversation/conversation_repository_port.dart';
import 'package:humsukhan/domain/conversation/turn_policy.dart';
import 'package:humsukhan/domain/professional/retention_policy.dart';
import 'package:humsukhan/domain/settings/app_settings.dart';
import 'package:humsukhan/domain/settings/settings_port.dart';
import 'package:humsukhan/domain/speech/language_tag.dart';
import 'package:humsukhan/infrastructure/storage/key_value_store.dart';
import 'package:humsukhan/infrastructure/storage/user_scope.dart';

/// Settings persisted as one JSON document per user.
final class PrefsSettingsStore implements SettingsPort {
  /// Creates a store.
  PrefsSettingsStore({
    required KeyValueStore store,
    required UserScope scope,
    AppLogger logger = const SilentLogger(),
  }) : _store = store,
       _scope = scope,
       _logger = logger;

  final KeyValueStore _store;
  final UserScope _scope;
  final AppLogger _logger;

  String get _key => _scope.key('settings');

  @override
  Future<Result<AppSettings, StorageFailure>> load() async {
    try {
      final String? raw = await _store.read(_key);
      if (raw == null) {
        return const Ok<AppSettings, StorageFailure>(AppSettings());
      }
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) {
        return const Ok<AppSettings, StorageFailure>(AppSettings());
      }
      return Ok<AppSettings, StorageFailure>(_fromJson(decoded));
    } on Object catch (error, stackTrace) {
      _logger.log(
        LogLevel.error,
        'settings',
        'could not read settings',
        error: error,
        stackTrace: stackTrace,
      );
      return Err<AppSettings, StorageFailure>(
        StorageFailure(FailureCode.storageReadFailed, detail: '$error'),
      );
    }
  }

  @override
  Future<Result<Unit, StorageFailure>> save(AppSettings settings) async {
    try {
      await _store.write(_key, jsonEncode(_toJson(settings)));
      return const Ok<Unit, StorageFailure>(unit);
    } on Object catch (error, stackTrace) {
      _logger.log(
        LogLevel.error,
        'settings',
        'could not write settings',
        error: error,
        stackTrace: stackTrace,
      );
      return Err<Unit, StorageFailure>(
        StorageFailure(FailureCode.storageWriteFailed, detail: '$error'),
      );
    }
  }

  static Map<String, Object?> _toJson(AppSettings s) => <String, Object?>{
    'appLanguage': s.appLanguage.code,
    'captionLanguage': s.captionLanguage.code,
    'darkMode': s.darkMode,
    'highContrast': s.highContrast,
    'largeText': s.largeText,
    'captionScale': s.captionScale,
    'pauseThreshold': s.pauseThreshold.name,
    'retentionDays': s.retentionDays,
    'alertHaptic': s.alertChannels.haptic,
    'alertVisual': s.alertChannels.visual,
    'alertTorch': s.alertChannels.torch,
    'alertScreenFlash': s.alertChannels.screenFlash,
    'onboardingComplete': s.onboardingComplete,
    'monitoringEnabled': s.monitoringEnabled,
  };

  static AppSettings _fromJson(Map<String, Object?> json) {
    bool flag(String key, {required bool fallback}) {
      final Object? value = json[key];
      return value is bool ? value : fallback;
    }

    final Object? scale = json['captionScale'];
    final Object? retention = json['retentionDays'];

    return AppSettings(
      appLanguage: AppLanguage.fromCode(json['appLanguage'] as String?),
      captionLanguage:
          LanguageTag.tryParse(json['captionLanguage'] as String?) ??
          LanguageTag.english,
      darkMode: flag('darkMode', fallback: false),
      highContrast: flag('highContrast', fallback: false),
      largeText: flag('largeText', fallback: false),
      captionScale: scale is num ? scale.toDouble().clamp(0.8, 2.0) : 1.0,
      pauseThreshold: PauseThreshold.fromName(
        json['pauseThreshold'] as String?,
      ),
      retentionDays: RetentionPolicy(retention is num ? retention.toInt() : 7)
          .days,
      alertChannels: AlertChannels(
        haptic: flag('alertHaptic', fallback: true),
        visual: flag('alertVisual', fallback: true),
        torch: flag('alertTorch', fallback: false),
        screenFlash: flag('alertScreenFlash', fallback: true),
      ),
      onboardingComplete: flag('onboardingComplete', fallback: false),
      monitoringEnabled: flag('monitoringEnabled', fallback: false),
    );
  }
}
