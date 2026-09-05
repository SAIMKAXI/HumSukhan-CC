import 'dart:async';
import 'dart:io' show Platform;

import 'package:humsukhan/core/time/clock.dart';
import 'package:humsukhan/core/failure/failure.dart';
import 'package:humsukhan/core/logging/app_logger.dart';
import 'package:humsukhan/domain/speech/capability.dart';
import 'package:humsukhan/domain/speech/language_tag.dart';
import 'package:humsukhan/infrastructure/tts/native_tts_adapter.dart';

/// Everything that can change a capability answer.
///
/// Installing a different speech engine, upgrading the OS, or adding a language
/// pack all change the key, so a stale answer cannot survive any of them (B9).
final class CapabilityKey {
  /// Creates a key.
  const CapabilityKey({
    required this.platform,
    required this.osVersion,
    required this.engineId,
    required this.language,
    required this.facility,
  });

  /// `android`, `ios`, …
  final String platform;

  /// The OS build string.
  final String osVersion;

  /// Which engine answered.
  final String engineId;

  /// Which language was asked about.
  final LanguageTag language;

  /// `stt` or `tts`.
  final String facility;

  @override
  bool operator ==(Object other) =>
      other is CapabilityKey &&
      other.platform == platform &&
      other.osVersion == osVersion &&
      other.engineId == engineId &&
      other.language == language &&
      other.facility == facility;

  @override
  int get hashCode =>
      Object.hash(platform, osVersion, engineId, language, facility);

  @override
  String toString() =>
      '$facility/$platform/$osVersion/$engineId/${language.code}';
}

final class _CachedCapability {
  const _CachedCapability(this.capability, this.checkedAt);

  final Capability capability;
  final DateTime checkedAt;
}

/// Answers what this device can do, per language, silently.
///
/// Positives are reused for the life of the process. Negatives expire, because
/// a device that gains an Urdu voice must be able to discover it — the shipped
/// bug never rechecked and so permanently disabled working hardware (B9).
final class SpeechCapabilityService implements SpeechCapabilityPort {
  /// Creates a capability service.
  SpeechCapabilityService({
    required NativeTtsAdapter tts,
    required bool hasCloudFallback,
    required bool hasRecognitionBackend,
    Clock clock = const SystemClock(),
    AppLogger logger = const SilentLogger(),
    this.negativeTtl = const Duration(minutes: 30),
    String? platformOverride,
    String? osVersionOverride,
  }) : _tts = tts,
       _hasCloudFallback = hasCloudFallback,
       _hasRecognitionBackend = hasRecognitionBackend,
       _clock = clock,
       _logger = logger,
       _platform = platformOverride ?? _detectPlatform(),
       _osVersion = osVersionOverride ?? _detectOsVersion();

  static String _detectPlatform() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return Platform.operatingSystem;
  }

  static String _detectOsVersion() => Platform.operatingSystemVersion;

  final NativeTtsAdapter _tts;
  final bool _hasCloudFallback;
  final bool _hasRecognitionBackend;
  final Clock _clock;
  final AppLogger _logger;
  final String _platform;
  final String _osVersion;

  /// How long a negative answer is trusted before it is re-probed.
  final Duration negativeTtl;

  final Map<CapabilityKey, _CachedCapability> _cache =
      <CapabilityKey, _CachedCapability>{};

  @override
  Future<Capability> stt(LanguageTag language) async {
    // Recognition runs server-side, so the only question is whether a backend
    // is configured at all. Both languages are supported by the model.
    if (!_hasRecognitionBackend) {
      return const CapabilityUnavailable(FailureCode.sttAuthFailed);
    }
    return const CapabilityAvailable();
  }

  @override
  Future<Capability> tts(LanguageTag language) async {
    final String engine = await _tts.engineId();
    final CapabilityKey key = CapabilityKey(
      platform: _platform,
      osVersion: _osVersion,
      engineId: engine,
      language: language,
      facility: 'tts',
    );

    final _CachedCapability? cached = _cache[key];
    if (cached != null && !_isStale(cached)) return cached.capability;

    // A query, never an utterance. Nothing audible happens here (B5).
    final bool supported = await _tts.supports(language);
    final Capability capability = supported
        ? const CapabilityAvailable()
        : _hasCloudFallback
        ? const CapabilityAvailable(locale: 'cloud')
        : const CapabilityUnavailable(FailureCode.ttsVoiceMissing);

    _cache[key] = _CachedCapability(capability, _clock.now());
    _logger.log(LogLevel.debug, 'capability', '$key -> $capability');
    return capability;
  }

  @override
  Future<void> invalidate() async {
    _cache.removeWhere(
      (CapabilityKey key, _CachedCapability value) =>
          !value.capability.isAvailable,
    );
  }

  bool _isStale(_CachedCapability cached) {
    if (cached.capability.isAvailable) return false;
    return _clock.now().difference(cached.checkedAt) >= negativeTtl;
  }
}
