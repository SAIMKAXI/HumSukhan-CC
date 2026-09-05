import 'package:humsukhan/core/failure/failure.dart';
import 'package:humsukhan/domain/conversation/caption.dart';
import 'package:humsukhan/domain/conversation/turn_policy.dart';
import 'package:humsukhan/domain/speech/tts_port.dart';

/// Where the conversation is in its life, as the screen sees it.
enum ConversationStage {
  /// Not started. The privacy notice and "Start conversation" are shown.
  idle,

  /// Running.
  active,

  /// Stopped, waiting for the user to save, delete, or continue.
  saveDecision,
}

/// What the recogniser is doing.
///
/// `reconnecting` and `failed` are states the UI renders, not internal booleans.
/// That is what makes "it silently stopped" impossible to express.
enum ListeningPhase {
  /// The microphone is closed.
  idle,

  /// Start has been asked for and has not completed.
  starting,

  /// Open, nothing being said right now.
  listening,

  /// Open, the other person is mid-utterance.
  speaking,

  /// The transport dropped and is being re-established.
  reconnecting,

  /// Recognition stopped because something went wrong.
  failed,
}

/// Everything the Everyday screen renders.
final class ConversationSessionState {
  /// Creates a session state.
  const ConversationSessionState({
    this.stage = ConversationStage.idle,
    this.phase = ListeningPhase.idle,
    this.captions = const <Caption>[],
    this.partialText = '',
    this.threshold = PauseThreshold.natural,
    this.failure,
    this.reconnectAttempt = 0,
    this.ttsActivity = TtsActivity.idle,
    this.speakingCaptionId,
    this.isBusy = false,
    this.startedAt,
  });

  /// Whether the conversation is running, stopped, or awaiting a save decision.
  final ConversationStage stage;

  /// What the recogniser is doing.
  final ListeningPhase phase;

  /// Committed captions, oldest first.
  final List<Caption> captions;

  /// The live, uncommitted text. Rendered as one extra bubble, never merged
  /// into [captions] until it is committed.
  final String partialText;

  /// The pause rule in force.
  final PauseThreshold threshold;

  /// Why recognition stopped, when [phase] is [ListeningPhase.failed].
  final Failure? failure;

  /// Which reconnection attempt is in flight.
  final int reconnectAttempt;

  /// What the synthesiser is doing.
  final TtsActivity ttsActivity;

  /// Which caption is being spoken, by id.
  ///
  /// By id, never by text: comparing text made two identical captions both show
  /// the stop icon (design.md §9).
  final String? speakingCaptionId;

  /// Whether a user-triggered operation is in flight.
  final bool isBusy;

  /// When the conversation started.
  final DateTime? startedAt;

  /// Whether the microphone is open in any form.
  bool get isMicrophoneOpen =>
      phase == ListeningPhase.starting ||
      phase == ListeningPhase.listening ||
      phase == ListeningPhase.speaking ||
      phase == ListeningPhase.reconnecting;

  /// Whether the app is currently producing audio.
  bool get isSpeaking => ttsActivity != TtsActivity.idle;

  /// Whether typing and speaking should be disabled, and why the UI says so.
  bool get inputLocked => isMicrophoneOpen || isBusy || isSpeaking;

  /// Whether anything has been captured.
  bool get hasContent => captions.isNotEmpty;

  /// A copy with the given fields replaced.
  ///
  /// [failure] and [speakingCaptionId] are cleared with the explicit
  /// `clearFailure` / `clearSpeakingCaption` flags, because passing `null` to a
  /// copy method cannot distinguish "unchanged" from "cleared".
  ConversationSessionState copyWith({
    ConversationStage? stage,
    ListeningPhase? phase,
    List<Caption>? captions,
    String? partialText,
    PauseThreshold? threshold,
    Failure? failure,
    bool clearFailure = false,
    int? reconnectAttempt,
    TtsActivity? ttsActivity,
    String? speakingCaptionId,
    bool clearSpeakingCaption = false,
    bool? isBusy,
    DateTime? startedAt,
  }) => ConversationSessionState(
    stage: stage ?? this.stage,
    phase: phase ?? this.phase,
    captions: captions ?? this.captions,
    partialText: partialText ?? this.partialText,
    threshold: threshold ?? this.threshold,
    failure: clearFailure ? null : (failure ?? this.failure),
    reconnectAttempt: reconnectAttempt ?? this.reconnectAttempt,
    ttsActivity: ttsActivity ?? this.ttsActivity,
    speakingCaptionId: clearSpeakingCaption
        ? null
        : (speakingCaptionId ?? this.speakingCaptionId),
    isBusy: isBusy ?? this.isBusy,
    startedAt: startedAt ?? this.startedAt,
  );

  @override
  String toString() =>
      'ConversationSessionState(${stage.name}/${phase.name}, '
      '${captions.length} captions, partial: "$partialText")';
}
