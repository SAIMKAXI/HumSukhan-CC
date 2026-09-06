import 'dart:async';
import 'dart:io' show Platform;

import 'package:humsukhan/core/time/clock.dart';
import 'package:humsukhan/core/failure/failure.dart';
import 'package:humsukhan/core/logging/app_logger.dart';
import 'package:humsukhan/domain/speech/capability.dart';
import 'package:humsukhan/domain/speech/language_tag.dart';

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
    required VoiceCataloguePort voices,
    required RecognitionCataloguePort recognisers,
    required bool hasCloudFallback,
    required bool hasRecognitionBackend,
    Clock clock = const SystemClock(),
    AppLogger logger = const SilentLogger(),
    this.negativeTtl = const Duration(minutes: 30),
    String? platformOverride,
    String? osVersionOverride,
  }) : _voices = voices,
       _recognisers = recognisers,
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

  final VoiceCataloguePort _voices;
  final RecognitionCataloguePort _recognisers;
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
    final CapabilityKey key = CapabilityKey(
      platform: _platform,
      osVersion: _osVersion,
      // The recogniser exposes no engine identity, so the locale set stands in
      // for one: gaining a language changes the answer, which is exactly the
      // event a stale cache must not survive.
      engineId: 'device-recogniser',
      language: language,
      facility: 'stt',
    );

    final _CachedCapability? cached = _cache[key];
    if (cached != null && !_isStale(cached)) return cached.capability;

    final Capability capability = await _probeStt(language);

    // An unknown answer is never cached: the next resume asks again.
    if (capability is! CapabilityUnknown) {
      _cache[key] = _CachedCapability(capability, _clock.now());
    }
    _logger.log(LogLevel.debug, 'capability', '$key -> $capability');
    return capability;
  }

  Future<Capability> _probeStt(LanguageTag language) async {
    // The device first: recognition that runs here needs no account, no key
    // and no signal, and it is what makes the app work the moment it is
    // installed. The backend is a fallback, not the plan.
    if (await _recognisers.isAvailable()) {
      final Set<String> locales = await _recognisers.availableLocales();
      if (locales.isEmpty) {
        // The engine did not answer. Not the same as having no languages —
        // and calling it unavailable would send the user to install something
        // they may well already have.
        return _hasRecognitionBackend
            ? const CapabilityAvailable(locale: 'cloud')
            : const CapabilityUnknown();
      }
      if (_matches(locales, language)) return const CapabilityAvailable();
    }

    if (_hasRecognitionBackend) {
      return const CapabilityAvailable(locale: 'cloud');
    }
    // Recoverable by exactly one action, which the guided install performs.
    return const CapabilityUnavailable(FailureCode.sttLanguageUnsupported);
  }

  /// Whether [locales] covers [language], without ever letting one language
  /// stand in for another.
  static bool _matches(Set<String> locales, LanguageTag language) {
    for (final String candidate in <String>[
      language.preferredLocale,
      ...language.fallbackLocales,
    ]) {
      final String needle = candidate.toLowerCase().replaceAll('_', '-');
      if (locales.contains(needle)) return true;
      for (final String locale in locales) {
        if (locale.replaceAll('_', '-') == needle) return true;
        // `ur` matches `ur-pk`; `en` must never match `ur-pk`.
        if (locale.startsWith('$needle-')) return true;
      }
    }
    return false;
  }

  @override
  Future<Capability> tts(LanguageTag language) async {
    final String engine = await _voices.engineId();
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
    final Set<String> locales = await _voices.availableLocales();
    final Capability capability;
    if (locales.isEmpty) {
      // The engine did not answer. That is not the same as "no voice": saying
      // a language is unavailable when we simply could not ask would send the
      // user to install something they may already have.
      capability = const CapabilityUnknown();
    } else if (await _voices.supports(language)) {
      capability = const CapabilityAvailable();
    } else if (_hasCloudFallback) {
      capability = const CapabilityAvailable(locale: 'cloud');
    } else {
      capability = const CapabilityUnavailable(FailureCode.ttsVoiceMissing);
    }

    // An unknown answer is never cached: the next resume asks again.
    if (capability is! CapabilityUnknown) {
      _cache[key] = _CachedCapability(capability, _clock.now());
    }
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
