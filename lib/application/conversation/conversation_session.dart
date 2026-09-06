import 'dart:async';

import 'package:humsukhan/core/time/clock.dart';
import 'package:humsukhan/core/id/id_generator.dart';
import 'package:humsukhan/application/conversation/conversation_session_state.dart';
import 'package:humsukhan/core/failure/failure.dart';
import 'package:humsukhan/core/logging/app_logger.dart';
import 'package:humsukhan/core/result/result.dart';
import 'package:humsukhan/domain/conversation/caption.dart';
import 'package:humsukhan/domain/conversation/conversation.dart';
import 'package:humsukhan/domain/conversation/turn_policy.dart';
import 'package:humsukhan/domain/speech/language_policy.dart';
import 'package:humsukhan/domain/speech/language_tag.dart';
import 'package:humsukhan/domain/speech/speech_failure.dart';
import 'package:humsukhan/domain/speech/stt_event.dart';
import 'package:humsukhan/domain/speech/stt_port.dart';
import 'package:humsukhan/domain/speech/tts_port.dart';
import 'package:humsukhan/domain/speech/utterance.dart';

/// The single owner of live speech state for Everyday mode.
///
/// Nothing else starts, stops or interprets the recogniser. Everything this
/// class needs is passed to its constructor — it never reaches into another
/// service's globals for a value it was already given (B1).
final class ConversationSession {
  /// Creates a session over the given ports.
  ConversationSession({
    required SttPort stt,
    required TtsPort tts,
    required IdGenerator ids,
    required Clock clock,
    required LanguageTag captionLanguage,
    PauseThreshold threshold = PauseThreshold.natural,
    AppLogger logger = const SilentLogger(),
  }) : _stt = stt,
       _tts = tts,
       _ids = ids,
       _clock = clock,
       _language = captionLanguage,
       _logger = logger,
       _turn = TurnState(threshold: threshold),
       _state = ConversationSessionState(threshold: threshold);

  final SttPort _stt;
  final TtsPort _tts;
  final IdGenerator _ids;
  final Clock _clock;
  final AppLogger _logger;

  LanguageTag _language;
  TurnState _turn;
  ConversationSessionState _state;

  final StreamController<ConversationSessionState> _states =
      StreamController<ConversationSessionState>.broadcast();

  StreamSubscription<SttEvent>? _sttSubscription;
  StreamSubscription<TtsActivity>? _ttsSubscription;
  Timer? _silenceTimer;

  /// Set synchronously before the first `await` of [startListening], so two
  /// rapid taps cannot both pass the check (B10).
  bool _startInFlight = false;

  /// Incremented on every start/stop. A long start-up that is superseded checks
  /// this after each await and abandons its work instead of clobbering state.
  int _generation = 0;

  bool _disposed = false;

  /// Whether the user asked for the current stop, as opposed to the transport
  /// dying. Decides whether an end event is ordinary or a failure.
  bool _stopRequested = false;

  /// The state right now.
  ConversationSessionState get state => _state;

  /// Every change to [state].
  Stream<ConversationSessionState> get states => _states.stream;

  /// The caption language in force.
  LanguageTag get captionLanguage => _language;

  /// Begins a conversation. The microphone stays closed until asked for.
  void begin() {
    if (_disposed) return;
    if (_state.stage == ConversationStage.active) return;
    _turn = TurnState(threshold: _state.threshold);
    _emit(
      _state.copyWith(
        stage: ConversationStage.active,
        phase: ListeningPhase.idle,
        captions: const <Caption>[],
        partialText: '',
        clearFailure: true,
        startedAt: _clock.now(),
      ),
    );
  }

  /// Changes the caption language for subsequent recognition.
  void setCaptionLanguage(LanguageTag language) {
    if (_disposed || _language == language) return;
    _language = language;
  }

  /// Changes the pause rule. Takes effect on the next signal.
  void setThreshold(PauseThreshold threshold) {
    if (_disposed) return;
    _turn = _turn.copyWith(threshold: threshold);
    _emit(_state.copyWith(threshold: threshold));
    if (_silenceTimer != null) _armSilenceTimer(threshold);
  }

  /// Opens the microphone.
  ///
  /// Returns [Err] when recognition could not be started; the failure is also
  /// reflected in [state] so the screen shows it without the caller doing
  /// anything. Never returns silently without changing state (B7).
  Future<Result<Unit, SttFailure>> startListening() async {
    if (_disposed) {
      return const Err<Unit, SttFailure>(
        SttFailure(FailureCode.cancelled, isRecoverable: false),
      );
    }
    if (_startInFlight || _state.isMicrophoneOpen) {
      _logger.log(
        LogLevel.debug,
        'conversation',
        'startListening ignored: already starting or open',
      );
      return const Ok<Unit, SttFailure>(unit);
    }

    // Guard first, await second.
    _startInFlight = true;
    final int generation = ++_generation;
    _stopRequested = false;

    _emit(
      _state.copyWith(
        stage: ConversationStage.active,
        phase: ListeningPhase.starting,
        clearFailure: true,
        reconnectAttempt: 0,
        startedAt: _state.startedAt ?? _clock.now(),
      ),
    );

    final Result<Unit, SttFailure> outcome = await _openTransport(generation);
    if (generation == _generation) _startInFlight = false;
    return outcome;
  }

  /// The awaited half of [startListening], split out so the re-entrancy guard
  /// is released on exactly one path rather than from inside a `finally` that
  /// would run before the returned future settles.
  Future<Result<Unit, SttFailure>> _openTransport(int generation) async {
    await _sttSubscription?.cancel();
    if (_isSuperseded(generation)) return const Ok<Unit, SttFailure>(unit);

    _sttSubscription = _stt.events.listen(
      _onSttEvent,
      // Never empty. A stream that dies has to say so (B4).
      onError: _onSttStreamError,
      onDone: _onSttStreamDone,
    );

    final Result<Unit, SttFailure> result = await _stt.start(
      SttRequest(language: _language),
    );
    if (_isSuperseded(generation)) return const Ok<Unit, SttFailure>(unit);

    return result.fold(
      (Unit _) {
        _applyTurnSignal(const TurnStarted());
        _emit(_state.copyWith(phase: ListeningPhase.listening));
        return const Ok<Unit, SttFailure>(unit);
      },
      (SttFailure failure) {
        _failWith(failure);
        return Err<Unit, SttFailure>(failure);
      },
    );
  }

  /// Closes the microphone, committing whatever was heard.
  ///
  /// A pause never calls this. Ending an utterance and ending the microphone are
  /// different events with different handlers (B2).
  Future<void> stopListening() async {
    if (_disposed || !_state.isMicrophoneOpen) return;
    _stopRequested = true;
    _generation++;
    _startInFlight = false;
    _cancelSilenceTimer();
    _applyTurnSignal(const UserStoppedTurn());
    _emit(_state.copyWith(phase: ListeningPhase.idle, partialText: ''));
    await _stt.stop();
  }

  /// Commits the current utterance without closing the microphone.
  void commitNow() {
    if (_disposed || !_state.isMicrophoneOpen) return;
    _applyTurnSignal(const UserCommitted());
  }

  /// Adds the user's own typed line to the conversation.
  ///
  /// Roman Urdu is normalised to Urdu script before it is stored, so the
  /// transcript is in one script (docs/instructions.md §6).
  Caption? sendTyped(String text) {
    if (_disposed) return null;
    final String cleaned = LanguagePolicy.collapseWhitespace(
      LanguagePolicy.stripDevanagari(text),
    );
    if (cleaned.isEmpty) return null;
    final String normalised = LanguagePolicy.normaliseRomanUrduToScript(
      cleaned,
    );
    final Caption caption = Caption(
      id: _ids.next(),
      text: normalised,
      speaker: CaptionSpeaker.own,
      createdAt: _clock.now(),
    );
    _emit(
      _state.copyWith(
        stage: ConversationStage.active,
        captions: <Caption>[..._state.captions, caption],
      ),
    );
    return caption;
  }

  /// Speaks [text] aloud, attributing the speech to [captionId] when it came
  /// from an existing caption.
  ///
  /// Always ends in a visible outcome: the returned [Result] carries the
  /// failure, and [state] carries it too (B8).
  Future<Result<Unit, TtsFailure>> speak(
    String text, {
    String? captionId,
    LanguageTag? language,
  }) async {
    if (_disposed) {
      return const Err<Unit, TtsFailure>(
        TtsFailure(FailureCode.cancelled, isRecoverable: false),
      );
    }
    final String cleaned = LanguagePolicy.stripDevanagari(text).trim();
    if (cleaned.isEmpty) {
      return const Err<Unit, TtsFailure>(TtsFailure(FailureCode.invalidInput));
    }

    final int generation = _generation;
    _emit(
      _state.copyWith(
        isBusy: true,
        speakingCaptionId: captionId,
        clearSpeakingCaption: captionId == null,
      ),
    );

    final Result<Unit, TtsFailure> result = await _tts.speak(
      Utterance(text: cleaned, language: language ?? languageOf(cleaned)),
    );

    // Liveness check before touching state (B15).
    if (_disposed) return result;
    if (generation == _generation) {
      _emit(_state.copyWith(isBusy: false, clearSpeakingCaption: true));
    }
    return result;
  }

  /// Stops any speech in progress.
  Future<void> stopSpeaking() async {
    if (_disposed) return;
    await _tts.stop();
    if (_disposed) return;
    _emit(_state.copyWith(clearSpeakingCaption: true, isBusy: false));
  }

  /// Ends the conversation and asks the user what to do with it.
  Future<void> stop() async {
    if (_disposed) return;
    await stopListening();
    await stopSpeaking();
    if (_disposed) return;
    _emit(
      _state.copyWith(
        stage: ConversationStage.saveDecision,
        phase: ListeningPhase.idle,
        partialText: '',
      ),
    );
  }

  /// Goes back to an active conversation after a save decision.
  void resume() {
    if (_disposed || _state.stage != ConversationStage.saveDecision) return;
    _emit(_state.copyWith(stage: ConversationStage.active));
  }

  /// The conversation as it would be saved.
  Conversation toConversation() => Conversation(
    id: _ids.next(),
    startedAt: _state.startedAt ?? _clock.now(),
    endedAt: _clock.now(),
    captions: List<Caption>.unmodifiable(_state.captions),
  );

  /// Clears everything and returns to idle.
  void reset() {
    if (_disposed) return;
    _turn = TurnState(threshold: _state.threshold);
    _emit(ConversationSessionState(threshold: _state.threshold));
  }

  /// Acknowledges a failure, returning the screen to a usable state.
  void acknowledgeFailure() {
    if (_disposed || _state.failure == null) return;
    _emit(_state.copyWith(clearFailure: true, phase: ListeningPhase.idle));
  }

  /// Releases the ports and stops emitting.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _cancelSilenceTimer();
    await _sttSubscription?.cancel();
    await _ttsSubscription?.cancel();
    await _states.close();
  }

  /// Begins mirroring [TtsPort.activity] into [state].
  void bindTtsActivity() {
    _ttsSubscription ??= _tts.activity.listen(
      (TtsActivity activity) {
        if (_disposed) return;
        _emit(
          _state.copyWith(
            ttsActivity: activity,
            clearSpeakingCaption: activity == TtsActivity.idle,
          ),
        );
      },
      onError: (Object error, StackTrace stackTrace) {
        _logger.log(
          LogLevel.warning,
          'conversation',
          'tts activity stream error',
          error: error,
          stackTrace: stackTrace,
        );
      },
    );
  }

  // ---- internals --------------------------------------------------------

  bool _isSuperseded(int generation) {
    if (_disposed) return true;
    return generation != _generation;
  }

  void _onSttEvent(SttEvent event) {
    if (_disposed) return;
    switch (event) {
      case SttPartial(:final String text):
        final String cleaned = LanguagePolicy.stripDevanagari(text);
        _applyTurnSignal(PartialReceived(cleaned));
        if (cleaned.trim().isNotEmpty &&
            _state.phase == ListeningPhase.listening) {
          _emit(_state.copyWith(phase: ListeningPhase.speaking));
        }

      case SttFinal(:final String text):
        _applyTurnSignal(FinalReceived(LanguagePolicy.stripDevanagari(text)));

      case SttReconnecting(:final int attempt):
        _cancelSilenceTimer();
        _emit(
          _state.copyWith(
            phase: ListeningPhase.reconnecting,
            reconnectAttempt: attempt,
          ),
        );

      case SttReconnected():
        _emit(
          _state.copyWith(
            phase: ListeningPhase.listening,
            reconnectAttempt: 0,
            clearFailure: true,
          ),
        );
        _armSilenceTimer(_turn.threshold);

      case SttEnded(:final SttEndReason reason):
        _cancelSilenceTimer();
        _applyTurnSignal(const RecognitionEnded());
        if (_stopRequested || reason == SttEndReason.stoppedByUser) {
          _emit(_state.copyWith(phase: ListeningPhase.idle, partialText: ''));
        } else {
          // The stream ended without anyone asking. That is a failure the user
          // has to see, not a quiet return to idle.
          _failWith(
            SttFailure(
              FailureCode.sttTransportLost,
              detail: 'ended: ${reason.name}',
            ),
          );
        }

      case SttFailed(:final SttFailure cause):
        _cancelSilenceTimer();
        _applyTurnSignal(const RecognitionEnded());
        _failWith(cause);
    }
  }

  void _onSttStreamError(Object error, StackTrace stackTrace) {
    _logger.log(
      LogLevel.error,
      'conversation',
      'recognition stream error',
      error: error,
      stackTrace: stackTrace,
    );
    if (_disposed) return;
    _cancelSilenceTimer();
    _applyTurnSignal(const RecognitionEnded());
    _failWith(SttFailure(FailureCode.sttTransportLost, detail: '$error'));
  }

  void _onSttStreamDone() {
    if (_disposed) return;
    if (!_state.isMicrophoneOpen) return;
    // The transport closed while we still believed we were listening.
    _cancelSilenceTimer();
    _applyTurnSignal(const RecognitionEnded());
    if (_stopRequested) {
      _emit(_state.copyWith(phase: ListeningPhase.idle, partialText: ''));
      return;
    }
    _failWith(
      const SttFailure(
        FailureCode.sttTransportLost,
        detail: 'stream closed without an end event',
      ),
    );
  }

  void _failWith(SttFailure failure) {
    _logger.log(
      LogLevel.warning,
      'conversation',
      'recognition failed: $failure',
    );
    _startInFlight = false;
    _emit(
      _state.copyWith(
        phase: ListeningPhase.failed,
        failure: failure,
        partialText: '',
      ),
    );
  }

  /// Runs one signal through the pure turn policy and applies its decision.
  void _applyTurnSignal(TurnSignal signal) {
    final TurnDecision decision = decideTurn(_turn, signal);
    _turn = decision.state;

    List<Caption> captions = _state.captions;
    final String? committed = decision.commit;
    if (committed != null && committed.trim().isNotEmpty) {
      captions = <Caption>[
        ..._state.captions,
        Caption(
          id: _ids.next(),
          text: LanguagePolicy.collapseWhitespace(committed),
          speaker: CaptionSpeaker.other,
          createdAt: _clock.now(),
        ),
      ];
    }

    ListeningPhase phase = _state.phase;
    if (decision.closeMicrophone) {
      phase = _state.phase == ListeningPhase.failed
          ? ListeningPhase.failed
          : ListeningPhase.idle;
    } else if (_state.phase == ListeningPhase.speaking &&
        decision.state.draft.isEmpty) {
      phase = ListeningPhase.listening;
    }

    _emit(
      _state.copyWith(
        captions: captions,
        partialText: decision.state.draft,
        phase: phase,
      ),
    );

    if (decision.cancelSilenceTimer) _cancelSilenceTimer();
    if (decision.restartSilenceTimer) _armSilenceTimer(_turn.threshold);
  }

  void _armSilenceTimer(PauseThreshold threshold) {
    _silenceTimer?.cancel();
    final Duration? duration = threshold.duration;
    if (duration == null) {
      _silenceTimer = null;
      return;
    }
    _silenceTimer = Timer(duration, () {
      if (_disposed) return;
      if (!_state.isMicrophoneOpen) return;
      // Commits the utterance. Deliberately not stopListening(): the whole
      // point of B2 is that these are different events.
      _applyTurnSignal(const SilenceElapsed());
    });
  }

  void _cancelSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = null;
  }

  /// Which language [text] will be spoken in.
  ///
  /// Public because the screen has to check the *right* voice before speaking:
  /// an Urdu reply inside an English conversation needs an Urdu voice, and
  /// asking about the session language would check the wrong one.
  LanguageTag languageOf(String text) =>
      switch (LanguagePolicy.classify(text)) {
        CaptionLanguage.urdu => LanguageTag.urdu,
        CaptionLanguage.romanUrdu => LanguageTag.urdu,
        CaptionLanguage.mixed => _language,
        CaptionLanguage.english => LanguageTag.english,
        CaptionLanguage.undetermined => _language,
      };

  void _emit(ConversationSessionState next) {
    if (_disposed) return;
    _state = next;
    if (!_states.isClosed) _states.add(next);
  }
}
