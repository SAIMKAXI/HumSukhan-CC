import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:humsukhan/core/failure/failure.dart';
import 'package:humsukhan/core/logging/app_logger.dart';
import 'package:humsukhan/core/result/result.dart';
import 'package:humsukhan/domain/speech/capability.dart';
import 'package:humsukhan/domain/speech/language_tag.dart';
import 'package:humsukhan/domain/speech/speech_failure.dart';
import 'package:humsukhan/domain/speech/tts_port.dart';
import 'package:humsukhan/domain/speech/utterance.dart';

/// The platform speech engine.
///
/// Speaks, and answers capability questions **without synthesising anything**:
/// the probe asks the engine which languages it has, it does not say a word.
/// The shipped bug spoke a full stop on every resume (B5).
final class NativeTtsAdapter implements TtsPort, VoiceCataloguePort {
  /// Creates an adapter.
  NativeTtsAdapter({
    FlutterTts? engine,
    AppLogger logger = const SilentLogger(),
  }) : _tts = engine ?? FlutterTts(),
       _logger = logger;

  final FlutterTts _tts;
  final AppLogger _logger;

  final StreamController<TtsActivity> _activity =
      StreamController<TtsActivity>.broadcast();

  Completer<void>? _speaking;
  bool _configured = false;
  bool _disposed = false;

  @override
  Stream<TtsActivity> get activity => _activity.stream;

  /// The locales the engine reports, lower-cased.
  ///
  /// A query, not an utterance: safe to call at any time, including on resume.
  @override
  Future<Set<String>> availableLocales() async {
    try {
      final Object? languages = await _tts.getLanguages;
      if (languages is! List<Object?>) return <String>{};
      return languages
          .whereType<Object>()
          .map((Object l) => l.toString().toLowerCase())
          .toSet();
    } on Object catch (error) {
      _logger.log(
        LogLevel.warning,
        'tts',
        'could not list languages',
        error: error,
      );
      return <String>{};
    }
  }

  /// An identifier for the engine in use, so a cache invalidates when the user
  /// installs a different one.
  @override
  Future<String> engineId() async {
    try {
      final Object? engine = await _tts.getDefaultEngine;
      return engine?.toString() ?? 'unknown';
    } on Object catch (error) {
      _logger.log(LogLevel.debug, 'tts', 'no default engine', error: error);
      return 'unknown';
    }
  }

  /// Whether the engine has a voice for [language], asked silently.
  @override
  Future<bool> supports(LanguageTag language) async {
    final Set<String> locales = await availableLocales();
    if (locales.isEmpty) return false;
    for (final String candidate in <String>[
      language.preferredLocale,
      ...language.fallbackLocales,
    ]) {
      final String needle = candidate.toLowerCase();
      if (locales.contains(needle)) return true;
      if (locales.any((String l) => l.replaceAll('_', '-') == needle)) {
        return true;
      }
      // `ur` matches `ur-PK`, but `en` must never match `ur-*`.
      if (locales.any((String l) => l.startsWith('$needle-'))) return true;
    }
    return false;
  }

  @override
  Future<Result<Unit, TtsFailure>> speak(Utterance utterance) async {
    if (_disposed) {
      return const Err<Unit, TtsFailure>(
        TtsFailure(FailureCode.cancelled, isRecoverable: false),
      );
    }
    if (utterance.isEmpty) {
      return const Err<Unit, TtsFailure>(TtsFailure(FailureCode.invalidInput));
    }

    try {
      await _configure();
      if (!await supports(utterance.language)) {
        return Err<Unit, TtsFailure>(
          TtsFailure(
            FailureCode.ttsVoiceMissing,
            detail: utterance.language.preferredLocale,
            isRecoverable: false,
          ),
        );
      }

      await _tts.setLanguage(utterance.language.preferredLocale);
      await _tts.setVolume(1);

      final Completer<void> completer = Completer<void>();
      _speaking = completer;
      _push(TtsActivity.preparing);

      final Object? result = await _tts.speak(utterance.text);
      if (result == 0) {
        _speaking = null;
        _push(TtsActivity.idle);
        return const Err<Unit, TtsFailure>(TtsFailure(FailureCode.ttsFailed));
      }

      // `awaitSpeakCompletion` makes speak() resolve when speech ends; the
      // handlers below are the belt to that braces.
      await completer.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () {
          _logger.log(LogLevel.warning, 'tts', 'speech completion timed out');
        },
      );
      return const Ok<Unit, TtsFailure>(unit);
    } on Object catch (error, stackTrace) {
      _logger.log(
        LogLevel.error,
        'tts',
        'speak failed',
        error: error,
        stackTrace: stackTrace,
      );
      _push(TtsActivity.idle);
      return Err<Unit, TtsFailure>(
        TtsFailure(FailureCode.ttsFailed, detail: '$error'),
      );
    } finally {
      _speaking = null;
      _push(TtsActivity.idle);
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } on Object catch (error) {
      _logger.log(LogLevel.debug, 'tts', 'stop raised', error: error);
    }
    _complete();
    _push(TtsActivity.idle);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await stop();
    await _activity.close();
  }

  Future<void> _configure() async {
    if (_configured) return;
    _configured = true;
    await _tts.awaitSpeakCompletion(true);
    _tts
      ..setStartHandler(() => _push(TtsActivity.speaking))
      ..setCompletionHandler(() {
        _complete();
        _push(TtsActivity.idle);
      })
      ..setCancelHandler(() {
        _complete();
        _push(TtsActivity.idle);
      })
      ..setErrorHandler((Object? message) {
        _logger.log(LogLevel.warning, 'tts', 'engine error: $message');
        _complete();
        _push(TtsActivity.idle);
      });
  }

  void _complete() {
    final Completer<void>? completer = _speaking;
    _speaking = null;
    if (completer != null && !completer.isCompleted) completer.complete();
  }

  void _push(TtsActivity value) {
    if (_disposed || _activity.isClosed) return;
    _activity.add(value);
  }
}
