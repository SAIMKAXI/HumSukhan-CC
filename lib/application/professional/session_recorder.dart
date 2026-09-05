import 'dart:async';

import 'package:humsukhan/core/time/clock.dart';
import 'package:humsukhan/core/id/id_generator.dart';
import 'package:humsukhan/core/failure/failure.dart';
import 'package:humsukhan/core/logging/app_logger.dart';
import 'package:humsukhan/core/result/result.dart';
import 'package:humsukhan/domain/conversation/caption.dart';
import 'package:humsukhan/domain/professional/professional_session.dart';
import 'package:humsukhan/domain/speech/language_policy.dart';
import 'package:humsukhan/domain/speech/language_tag.dart';
import 'package:humsukhan/domain/speech/speech_failure.dart';
import 'package:humsukhan/domain/speech/stt_event.dart';
import 'package:humsukhan/domain/speech/stt_port.dart';

/// What a recording is doing.
enum RecorderPhase {
  /// Nothing is being recorded.
  idle,

  /// Start has been asked for and has not completed.
  starting,

  /// Capturing.
  recording,

  /// The transport dropped; the adapter is restoring it. Capture resumes.
  reconnecting,

  /// Recording stopped because something went wrong.
  failed,

  /// Recording finished and is waiting to be saved or discarded.
  stopped,
}

/// What the Professional live screen renders.
final class RecorderState {
  /// Creates a recorder state.
  const RecorderState({
    this.phase = RecorderPhase.idle,
    this.session,
    this.failure,
    this.reconnectAttempt = 0,
    this.hasSpeechInFlight = false,
  });

  /// What the recording is doing.
  final RecorderPhase phase;

  /// The session being recorded, once one exists.
  final ProfessionalSession? session;

  /// Why recording stopped, when [phase] is [RecorderPhase.failed].
  final Failure? failure;

  /// Which reconnection attempt is running.
  final int reconnectAttempt;

  /// Whether the recogniser is mid-utterance.
  ///
  /// Deliberately a flag and not the text: Professional mode must never flicker
  /// half-recognised words into the transcript (design.md §5.6), and a boolean
  /// makes that structurally impossible rather than merely intended.
  final bool hasSpeechInFlight;

  /// Whether capture is running in some form.
  bool get isRecording =>
      phase == RecorderPhase.starting ||
      phase == RecorderPhase.recording ||
      phase == RecorderPhase.reconnecting;

  /// A copy with the given fields replaced.
  RecorderState copyWith({
    RecorderPhase? phase,
    ProfessionalSession? session,
    Failure? failure,
    bool clearFailure = false,
    int? reconnectAttempt,
    bool? hasSpeechInFlight,
  }) => RecorderState(
    phase: phase ?? this.phase,
    session: session ?? this.session,
    failure: clearFailure ? null : (failure ?? this.failure),
    reconnectAttempt: reconnectAttempt ?? this.reconnectAttempt,
    hasSpeechInFlight: hasSpeechInFlight ?? this.hasSpeechInFlight,
  );
}

/// Captures a long-form session into a transcript.
///
/// Owns exactly one recogniser subscription and one session. Interim results are
/// consumed and discarded; only finals become captions.
final class SessionRecorder {
  /// Creates a recorder over [stt].
  SessionRecorder({
    required SttPort stt,
    required IdGenerator ids,
    required Clock clock,
    AppLogger logger = const SilentLogger(),
  }) : _stt = stt,
       _ids = ids,
       _clock = clock,
       _logger = logger;

  final SttPort _stt;
  final IdGenerator _ids;
  final Clock _clock;
  final AppLogger _logger;

  final StreamController<RecorderState> _states =
      StreamController<RecorderState>.broadcast();

  RecorderState _state = const RecorderState();
  StreamSubscription<SttEvent>? _subscription;
  bool _startInFlight = false;
  bool _stopRequested = false;
  bool _disposed = false;
  int _generation = 0;

  /// The state right now.
  RecorderState get state => _state;

  /// Every change to [state].
  Stream<RecorderState> get states => _states.stream;

  /// Starts recording a new session.
  ///
  /// Returns [Err] when capture could not start; the failure is also in [state].
  Future<Result<ProfessionalSession, SttFailure>> start({
    required String title,
    required SessionType type,
    required LanguageTag language,
    required int retentionDays,
  }) async {
    if (_disposed) {
      return const Err<ProfessionalSession, SttFailure>(
        SttFailure(FailureCode.cancelled, isRecoverable: false),
      );
    }
    if (_startInFlight || _state.isRecording) {
      final ProfessionalSession? existing = _state.session;
      if (existing != null) {
        return Ok<ProfessionalSession, SttFailure>(existing);
      }
      return const Err<ProfessionalSession, SttFailure>(
        SttFailure(FailureCode.sttStartFailed, detail: 'already starting'),
      );
    }

    // Guard synchronously, before any await (B10).
    _startInFlight = true;
    final int generation = ++_generation;
    _stopRequested = false;

    final ProfessionalSession session = ProfessionalSession(
      id: _ids.next(),
      title: title,
      type: type,
      language: language,
      startedAt: _clock.now(),
      retentionDays: retentionDays,
    );
    _emit(RecorderState(phase: RecorderPhase.starting, session: session));

    final Result<ProfessionalSession, SttFailure> outcome =
        await _openTransport(generation, session, language);
    if (generation == _generation) _startInFlight = false;
    return outcome;
  }

  Future<Result<ProfessionalSession, SttFailure>> _openTransport(
    int generation,
    ProfessionalSession session,
    LanguageTag language,
  ) async {
    await _subscription?.cancel();
    if (_superseded(generation)) {
      return Ok<ProfessionalSession, SttFailure>(session);
    }

    _subscription = _stt.events.listen(
      _onEvent,
      onError: _onStreamError,
      onDone: _onStreamDone,
    );

    final Result<Unit, SttFailure> started = await _stt.start(
      SttRequest(language: language, profile: SttProfile.dictation),
    );
    if (_superseded(generation)) {
      return Ok<ProfessionalSession, SttFailure>(session);
    }

    return started.fold(
      (Unit _) {
        _emit(_state.copyWith(phase: RecorderPhase.recording));
        return Ok<ProfessionalSession, SttFailure>(session);
      },
      (SttFailure failure) {
        _fail(failure);
        return Err<ProfessionalSession, SttFailure>(failure);
      },
    );
  }

  /// Stops recording, keeping whatever was captured.
  Future<void> stop() async {
    if (_disposed || !_state.isRecording) return;
    _stopRequested = true;
    _generation++;
    _startInFlight = false;
    await _stt.stop();
    if (_disposed) return;
    _emit(
      _state.copyWith(
        phase: RecorderPhase.stopped,
        hasSpeechInFlight: false,
        session: _state.session?.copyWith(endedAt: _clock.now()),
      ),
    );
  }

  /// Adds a caption the user typed by hand.
  void addManualCaption(String text) {
    if (_disposed) return;
    final String cleaned = LanguagePolicy.collapseWhitespace(
      LanguagePolicy.stripDevanagari(text),
    );
    if (cleaned.isEmpty) return;
    _appendCaption(
      LanguagePolicy.normaliseRomanUrduToScript(cleaned),
      CaptionSpeaker.own,
    );
  }

  /// Discards the recording and returns to idle.
  void discard() {
    if (_disposed) return;
    _emit(const RecorderState());
  }

  /// Acknowledges a failure so the screen becomes usable again.
  void acknowledgeFailure() {
    if (_disposed || _state.failure == null) return;
    _emit(
      _state.copyWith(
        clearFailure: true,
        phase: _state.session == null
            ? RecorderPhase.idle
            : RecorderPhase.stopped,
      ),
    );
  }

  /// Releases the recogniser subscription.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _subscription?.cancel();
    await _states.close();
  }

  bool _superseded(int generation) => _disposed || generation != _generation;

  void _onEvent(SttEvent event) {
    if (_disposed) return;
    switch (event) {
      case SttPartial(:final String text):
        // Consumed and dropped. Interim text never reaches the transcript.
        _emit(_state.copyWith(hasSpeechInFlight: text.trim().isNotEmpty));

      case SttFinal(:final String text):
        final String cleaned = LanguagePolicy.collapseWhitespace(
          LanguagePolicy.stripDevanagari(text),
        );
        _emit(_state.copyWith(hasSpeechInFlight: false));
        if (cleaned.isEmpty) return;
        _appendCaption(cleaned, CaptionSpeaker.other);

      case SttReconnecting(:final int attempt):
        _emit(
          _state.copyWith(
            phase: RecorderPhase.reconnecting,
            reconnectAttempt: attempt,
            hasSpeechInFlight: false,
          ),
        );

      case SttReconnected():
        _emit(
          _state.copyWith(
            phase: RecorderPhase.recording,
            reconnectAttempt: 0,
            clearFailure: true,
          ),
        );

      case SttEnded(:final SttEndReason reason):
        if (_stopRequested || reason == SttEndReason.stoppedByUser) {
          _emit(
            _state.copyWith(
              phase: RecorderPhase.stopped,
              hasSpeechInFlight: false,
            ),
          );
        } else {
          _fail(
            SttFailure(
              FailureCode.sttTransportLost,
              detail: 'ended: ${reason.name}',
            ),
          );
        }

      case SttFailed(:final SttFailure cause):
        _fail(cause);
    }
  }

  void _onStreamError(Object error, StackTrace stackTrace) {
    _logger.log(
      LogLevel.error,
      'recorder',
      'recognition stream error',
      error: error,
      stackTrace: stackTrace,
    );
    if (_disposed) return;
    _fail(SttFailure(FailureCode.sttTransportLost, detail: '$error'));
  }

  void _onStreamDone() {
    if (_disposed || !_state.isRecording) return;
    if (_stopRequested) {
      _emit(_state.copyWith(phase: RecorderPhase.stopped));
      return;
    }
    _fail(
      const SttFailure(
        FailureCode.sttTransportLost,
        detail: 'stream closed without an end event',
      ),
    );
  }

  void _fail(SttFailure failure) {
    _logger.log(LogLevel.warning, 'recorder', 'recording failed: $failure');
    _startInFlight = false;
    // Whatever was captured stays in the session. A failure loses the
    // connection, never the transcript.
    _emit(
      _state.copyWith(
        phase: RecorderPhase.failed,
        failure: failure,
        hasSpeechInFlight: false,
        session: _state.session?.copyWith(endedAt: _clock.now()),
      ),
    );
  }

  void _appendCaption(String text, CaptionSpeaker speaker) {
    final ProfessionalSession? session = _state.session;
    if (session == null) return;
    final Caption caption = Caption(
      id: _ids.next(),
      text: text,
      speaker: speaker,
      createdAt: _clock.now(),
    );
    _emit(
      _state.copyWith(
        session: session.copyWith(
          captions: <Caption>[...session.captions, caption],
        ),
      ),
    );
  }

  void _emit(RecorderState next) {
    if (_disposed) return;
    _state = next;
    if (!_states.isClosed) _states.add(next);
  }
}
