import 'dart:async';

import 'package:humsukhan/core/failure/failure.dart';
import 'package:humsukhan/core/logging/app_logger.dart';
import 'package:humsukhan/core/result/result.dart';
import 'package:humsukhan/domain/speech/capability.dart';
import 'package:humsukhan/domain/speech/language_tag.dart';
import 'package:humsukhan/domain/speech/speech_failure.dart';
import 'package:humsukhan/domain/speech/stt_event.dart';
import 'package:humsukhan/domain/speech/stt_port.dart';
import 'package:humsukhan/infrastructure/stt/platform_recogniser.dart';

/// Recognition on the device itself, with no account, no key and no network.
///
/// This is the recogniser HumSukhan uses by default. It matters for three
/// reasons: it works the moment the app is installed, it keeps a private
/// conversation on the handset, and it keeps working on a train.
///
/// The hard part is not recognising — it is that every platform recogniser ends
/// its session on a pause of a second or two. A user talking for twenty minutes
/// gets hundreds of those. So a *segment* is the platform's unit and a
/// *session* is the product's, and this adapter restarts segments underneath a
/// session that the caller sees as continuous. A restart is deliberately not an
/// [SttReconnecting]: nothing is wrong, and telling the user something is wrong
/// every time they breathe would make working captions look broken.
final class NativeSttAdapter implements SttPort, RecognitionCataloguePort {
  /// Creates an adapter.
  NativeSttAdapter({
    required PlatformRecogniser recogniser,
    AppLogger logger = const SilentLogger(),
    this.restartDelay = const Duration(milliseconds: 120),
    this.maxConsecutiveFailures = 4,
  }) : _recogniser = recogniser,
       _logger = logger;

  final PlatformRecogniser _recogniser;
  final AppLogger _logger;

  /// How long to wait before starting the next segment.
  ///
  /// Long enough that Android has released the engine, short enough that the
  /// gap falls inside a natural pause between sentences.
  final Duration restartDelay;

  /// How many segments may fail back-to-back before the session gives up.
  ///
  /// Reset by any successful recognition, so a long session is not killed by
  /// occasional trouble — only by trouble that never stops.
  final int maxConsecutiveFailures;

  final StreamController<SttEvent> _events =
      StreamController<SttEvent>.broadcast();

  SttRequest? _request;
  String? _localeId;
  bool _listening = false;
  bool _stopping = false;
  bool _disposed = false;
  bool _onDevice = true;
  int _consecutiveFailures = 0;
  String _lastPartial = '';
  Timer? _restart;

  @override
  Stream<SttEvent> get events => _events.stream;

  /// Whether recognition ran without the network for the current session.
  ///
  /// Read by the UI to tell the user, truthfully, whether their words left the
  /// device — never asserted, only reported.
  bool get isOnDevice => _onDevice;

  @override
  Future<bool> isAvailable() => _recogniser.isAvailable();

  @override
  Future<Set<String>> availableLocales() => _recogniser.localeIds();

  @override
  Future<bool> supportsOffline(LanguageTag language) async {
    // The platform exposes no query for "can this locale run offline"; the only
    // honest answer is whether a model for the language exists at all. Claiming
    // more than the API can tell us would be a guess dressed as a fact.
    return await _resolveLocale(language) != null;
  }

  @override
  Future<Result<Unit, SttFailure>> start(SttRequest request) async {
    if (_disposed) {
      return const Err<Unit, SttFailure>(
        SttFailure(FailureCode.cancelled, isRecoverable: false),
      );
    }
    if (_listening) await stop();

    final bool ready = await _recogniser.initialise(
      onError: _onError,
      onStatus: _onStatus,
    );
    if (!ready) {
      return const Err<Unit, SttFailure>(
        SttFailure(FailureCode.sttStartFailed, isRecoverable: false),
      );
    }

    final String? locale = await _resolveLocale(request.language);
    if (locale == null) {
      // The one case the guided install flow exists for. Recoverable, because
      // installing the pack is exactly how the user recovers from it.
      return Err<Unit, SttFailure>(
        SttFailure(
          FailureCode.sttLanguageUnsupported,
          detail: request.language.preferredLocale,
        ),
      );
    }

    _request = request;
    _localeId = locale;
    _stopping = false;
    _consecutiveFailures = 0;
    _lastPartial = '';
    _onDevice = true;

    final SttFailure? failure = await _listenSegment();
    if (failure != null) {
      _request = null;
      _listening = false;
      return Err<Unit, SttFailure>(failure);
    }
    _listening = true;
    return const Ok<Unit, SttFailure>(unit);
  }

  @override
  Future<void> stop() async {
    if (!_listening && _request == null) return;
    _stopping = true;
    _restart?.cancel();
    _restart = null;
    await _recogniser.stop();
    _listening = false;
    _request = null;
    _emit(const SttEnded(SttEndReason.stoppedByUser));
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _restart?.cancel();
    _restart = null;
    if (_listening) await _recogniser.cancel();
    _listening = false;
    _request = null;
    await _events.close();
  }

  /// Starts one platform segment. Returns a failure only when the very first
  /// attempt cannot start; later trouble arrives through [_onError].
  Future<SttFailure?> _listenSegment() async {
    final SttRequest? request = _request;
    final String? locale = _localeId;
    if (request == null || locale == null || _disposed) return null;

    try {
      await _recogniser.listen(
        localeId: locale,
        partialResults: request.interimResults,
        onDevice: _onDevice,
        punctuate: request.punctuate,
        dictation: request.profile == SttProfile.dictation,
        // Android caps both of these itself; these are upper bounds, not
        // promises. A generous pause keeps a thinking speaker's turn intact.
        pauseFor: const Duration(seconds: 4),
        listenFor: const Duration(minutes: 5),
        onResult: _onResult,
      );
      return null;
    } on Object catch (error, stackTrace) {
      if (_onDevice) {
        // The engine has no offline model for this locale. Falling back to the
        // engine's own choice keeps captions working; it is a quieter outcome
        // than refusing to caption at all, and `isOnDevice` stops reporting
        // privacy we no longer have.
        _logger.log(
          LogLevel.info,
          'stt',
          'on-device listen refused; allowing the engine to choose',
          error: error,
        );
        _onDevice = false;
        return _listenSegment();
      }
      _logger.log(
        LogLevel.error,
        'stt',
        'listen failed',
        error: error,
        stackTrace: stackTrace,
      );
      return SttFailure(FailureCode.sttStartFailed, detail: '$error');
    }
  }

  void _onResult(RecognisedSpeech result) {
    if (_disposed || _stopping) return;
    final String text = result.text.trim();

    if (result.isFinal) {
      _consecutiveFailures = 0;
      _lastPartial = '';
      // An empty final is what a segment that heard nothing produces. Emitting
      // it would append a blank turn to the transcript on every pause.
      if (text.isEmpty) return;
      _emit(SttFinal(text, confidence: result.confidence));
      return;
    }

    if (text.isEmpty) {
      // A restarted segment opens with an empty partial. Passing it through
      // would blank the caption the user is mid-way through reading.
      return;
    }
    if (text == _lastPartial) return;
    _lastPartial = text;
    _emit(SttPartial(text));
  }

  void _onStatus(String status) {
    if (_disposed) return;
    // `done` and `notListening` are how both platforms announce the end of a
    // segment. While the session is still wanted, that is a cue to restart, not
    // an end — the shipped behaviour of treating it as an end is what made
    // captions stop after the first sentence.
    final bool ended = status == 'done' || status == 'notListening';
    if (!ended || _stopping || _request == null) return;
    _scheduleRestart();
  }

  void _onError(RecogniserError error) {
    if (_disposed || _stopping || _request == null) return;

    if (error.isSilence) {
      // Nobody spoke. Ordinary, and not worth a single pixel of UI.
      _scheduleRestart();
      return;
    }

    _consecutiveFailures++;
    _logger.log(
      LogLevel.warning,
      'stt',
      'recogniser error $error (${_consecutiveFailures}x)',
    );

    if (_consecutiveFailures >= maxConsecutiveFailures) {
      _fail(_map(error));
      return;
    }
    if (error.permanent && _isFatal(error)) {
      _fail(_map(error));
      return;
    }
    // Recoverable, or permanent for this segment only: say so, then try again.
    _emit(SttReconnecting(_consecutiveFailures));
    _scheduleRestart();
  }

  /// Whether an error means this session can never work, as opposed to this
  /// segment having gone wrong.
  bool _isFatal(RecogniserError error) => switch (error.code) {
    'error_permission' ||
    'error_insufficient_permissions' ||
    'error_language_not_supported' ||
    'error_language_unavailable' => true,
    _ => false,
  };

  SttFailure _map(RecogniserError error) => switch (error.code) {
    'error_permission' || 'error_insufficient_permissions' => const SttFailure(
      FailureCode.microphonePermissionDenied,
      isRecoverable: false,
    ),
    'error_language_not_supported' || 'error_language_unavailable' =>
      SttFailure(FailureCode.sttLanguageUnsupported, detail: _localeId),
    'error_network' ||
    'error_network_timeout' => const SttFailure(FailureCode.network),
    'error_busy' => const SttFailure(FailureCode.microphoneUnavailable),
    'error_audio' ||
    'error_client' => const SttFailure(FailureCode.microphoneUnavailable),
    _ => SttFailure(FailureCode.sttStartFailed, detail: error.code),
  };

  void _scheduleRestart() {
    if (_disposed || _stopping || _request == null) return;
    _restart?.cancel();
    _restart = Timer(restartDelay, () async {
      if (_disposed || _stopping || _request == null) return;
      final SttFailure? failure = await _listenSegment();
      if (failure != null) _fail(failure);
    });
  }

  void _fail(SttFailure failure) {
    _restart?.cancel();
    _restart = null;
    _listening = false;
    _request = null;
    unawaited(_recogniser.cancel());
    _emit(SttFailed(failure));
  }

  /// Picks the engine locale for [language], preferring the regional default
  /// and never substituting a different language for a missing one.
  Future<String?> _resolveLocale(LanguageTag language) async {
    final Set<String> available = await _recogniser.localeIds();
    if (available.isEmpty) return null;

    for (final String candidate in <String>[
      language.preferredLocale,
      ...language.fallbackLocales,
    ]) {
      final String needle = candidate.toLowerCase().replaceAll('_', '-');
      if (available.contains(needle)) return needle;
      // `ur` should find `ur-pk`; `en` must never find `ur-pk`.
      for (final String locale in available) {
        if (locale.startsWith('$needle-')) return locale;
      }
    }
    return null;
  }

  void _emit(SttEvent event) {
    if (_disposed || _events.isClosed) return;
    _events.add(event);
  }
}
