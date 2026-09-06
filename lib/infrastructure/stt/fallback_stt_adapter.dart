import 'dart:async';

import 'package:humsukhan/core/failure/failure.dart';
import 'package:humsukhan/core/logging/app_logger.dart';
import 'package:humsukhan/core/result/result.dart';
import 'package:humsukhan/domain/speech/speech_failure.dart';
import 'package:humsukhan/domain/speech/stt_event.dart';
import 'package:humsukhan/domain/speech/stt_port.dart';

/// Recognises on the device, and falls back to a server only when the device
/// genuinely cannot.
///
/// The order matters and is the point: on-device recognition needs no account,
/// no key and no signal, so it is what makes the app work the moment it is
/// installed and what keeps a private conversation on the handset. The server
/// exists for the device that has no model for the user's language and no way
/// to fetch one.
///
/// Only one engine is ever live. Events are forwarded from whichever started,
/// so the session state machine upstream sees a single, ordinary stream.
final class FallbackSttAdapter implements SttPort {
  /// Creates a composite adapter.
  FallbackSttAdapter({
    required SttPort primary,
    SttPort? fallback,
    AppLogger logger = const SilentLogger(),
  }) : _primary = primary,
       _fallback = fallback,
       _logger = logger;

  final SttPort _primary;
  final SttPort? _fallback;
  final AppLogger _logger;

  final StreamController<SttEvent> _events =
      StreamController<SttEvent>.broadcast();

  StreamSubscription<SttEvent>? _forwarding;
  SttPort? _active;
  bool _disposed = false;

  @override
  Stream<SttEvent> get events => _events.stream;

  /// Whether the current session is running on the device.
  ///
  /// Read by the UI to tell the user, truthfully, whether their words are
  /// leaving the handset.
  bool get isOnDevice => _active == null || identical(_active, _primary);

  @override
  Future<Result<Unit, SttFailure>> start(SttRequest request) async {
    if (_disposed) {
      return const Err<Unit, SttFailure>(
        SttFailure(FailureCode.cancelled, isRecoverable: false),
      );
    }
    await _detach();

    final Result<Unit, SttFailure> primary = await _tryStart(_primary, request);
    if (primary.isOk) return primary;

    final SttPort? secondary = _fallback;
    final SttFailure reason = primary.errorOrNull!;
    if (secondary == null) return primary;

    // A microphone the user has blocked will not be unblocked by trying a
    // different recogniser, and retrying would only delay the one message that
    // helps. Only a device that cannot do the language is worth escalating.
    if (reason.code != FailureCode.sttLanguageUnsupported &&
        reason.code != FailureCode.sttStartFailed) {
      return primary;
    }

    _logger.log(
      LogLevel.info,
      'stt',
      'device recogniser unavailable (${reason.code.name}); using the server',
    );
    final Result<Unit, SttFailure> backup = await _tryStart(secondary, request);
    // The device's reason is the one the user can act on — a language pack can
    // be installed, "the server said no" cannot — so it is what survives when
    // both fail.
    return backup.isOk ? backup : primary;
  }

  Future<Result<Unit, SttFailure>> _tryStart(
    SttPort port,
    SttRequest request,
  ) async {
    final Result<Unit, SttFailure> result = await port.start(request);
    if (result.isOk) {
      _active = port;
      _forwarding = port.events.listen(
        _emit,
        onError: (Object error, StackTrace stackTrace) {
          _logger.log(
            LogLevel.error,
            'stt',
            'recogniser stream error',
            error: error,
            stackTrace: stackTrace,
          );
          _emit(
            SttFailed(SttFailure(FailureCode.sttStartFailed, detail: '$error')),
          );
        },
      );
    }
    return result;
  }

  @override
  Future<void> stop() async {
    final SttPort? active = _active;
    if (active == null) return;
    await active.stop();
    await _detach();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _forwarding?.cancel();
    _forwarding = null;
    _active = null;
    await _primary.dispose();
    await _fallback?.dispose();
    await _events.close();
  }

  Future<void> _detach() async {
    await _forwarding?.cancel();
    _forwarding = null;
    _active = null;
  }

  void _emit(SttEvent event) {
    if (_disposed || _events.isClosed) return;
    _events.add(event);
  }
}
