import 'dart:async';

import 'package:humsukhan/core/failure/failure.dart';
import 'package:humsukhan/core/logging/app_logger.dart';
import 'package:humsukhan/core/result/result.dart';
import 'package:humsukhan/domain/speech/speech_failure.dart';
import 'package:humsukhan/domain/speech/tts_port.dart';
import 'package:humsukhan/domain/speech/utterance.dart';

/// Speaks through the platform engine, and falls back to the cloud when it
/// cannot.
///
/// This is the single [TtsPort] the app wires. It never throws: when both
/// engines fail the caller gets an [Err] carrying the *platform* reason, which
/// is the one the user can act on ("install an Urdu voice").
final class FallbackTtsAdapter implements TtsPort {
  /// Creates a composite adapter.
  FallbackTtsAdapter({
    required TtsPort primary,
    TtsPort? fallback,
    AppLogger logger = const SilentLogger(),
  }) : _primary = primary,
       _fallback = fallback,
       _logger = logger {
    _subscriptions.add(
      _primary.activity.listen(_push, onError: _onStreamError),
    );
    final TtsPort? secondary = _fallback;
    if (secondary != null) {
      _subscriptions.add(
        secondary.activity.listen(_push, onError: _onStreamError),
      );
    }
  }

  final TtsPort _primary;
  final TtsPort? _fallback;
  final AppLogger _logger;
  final List<StreamSubscription<TtsActivity>> _subscriptions =
      <StreamSubscription<TtsActivity>>[];

  final StreamController<TtsActivity> _activity =
      StreamController<TtsActivity>.broadcast();

  bool _disposed = false;

  @override
  Stream<TtsActivity> get activity => _activity.stream;

  @override
  Future<Result<Unit, TtsFailure>> speak(Utterance utterance) async {
    if (_disposed) {
      return const Err<Unit, TtsFailure>(
        TtsFailure(FailureCode.cancelled, isRecoverable: false),
      );
    }

    final Result<Unit, TtsFailure> primary = await _primary.speak(utterance);
    if (primary.isOk) return primary;

    final TtsFailure platformFailure = (primary as Err<Unit, TtsFailure>).error;
    final TtsPort? fallback = _fallback;
    if (fallback == null) return primary;

    _logger.log(
      LogLevel.info,
      'tts',
      'platform engine failed (${platformFailure.code.name}); trying the cloud',
    );

    final Result<Unit, TtsFailure> cloud = await fallback.speak(utterance);
    if (cloud.isOk) return cloud;

    // Both failed. Report the platform reason: it is the one with a remedy the
    // user can act on.
    return Err<Unit, TtsFailure>(
      TtsFailure(
        platformFailure.code,
        detail:
            'platform: ${platformFailure.detail ?? platformFailure.code.name}; '
            'cloud: ${(cloud as Err<Unit, TtsFailure>).error.detail ?? cloud.error.code.name}',
        isRecoverable: platformFailure.isRecoverable,
      ),
    );
  }

  @override
  Future<void> stop() async {
    await _primary.stop();
    await _fallback?.stop();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final StreamSubscription<TtsActivity> subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _primary.dispose();
    await _fallback?.dispose();
    await _activity.close();
  }

  void _onStreamError(Object error, StackTrace stackTrace) {
    _logger.log(
      LogLevel.warning,
      'tts',
      'activity stream error',
      error: error,
      stackTrace: stackTrace,
    );
  }

  void _push(TtsActivity value) {
    if (_disposed || _activity.isClosed) return;
    _activity.add(value);
  }
}
