/// Turn segmentation as a pure function.
///
/// Two shipped defects live here (docs/instructions.md §5.1 B2 and B3):
/// a pause once closed the microphone, and finals once overwrote each other.
/// Both are now decisions this file makes, with no plugin in sight.
library;

/// How long a silence must last before the current utterance is committed.
enum PauseThreshold {
  /// 1.2 seconds.
  short(Duration(milliseconds: 1200)),

  /// 1.7 seconds.
  natural(Duration(milliseconds: 1700)),

  /// 2.5 seconds.
  patient(Duration(milliseconds: 2500)),

  /// Never commit on silence; the user commits by hand.
  manual(null);

  const PauseThreshold(this.duration);

  /// The silence required, or `null` when only the user commits.
  final Duration? duration;

  /// Whether silence ever commits an utterance under this setting.
  bool get commitsOnSilence => duration != null;

  /// Parses a stored name, defaulting to [PauseThreshold.natural].
  static PauseThreshold fromName(String? name) =>
      PauseThreshold.values.firstWhere(
        (PauseThreshold t) => t.name == name,
        orElse: () => PauseThreshold.natural,
      );
}

/// What the turn machine knows between signals.
final class TurnState {
  /// Creates a turn state.
  const TurnState({
    this.committedText = '',
    this.pendingFinal = '',
    this.partial = '',
    this.threshold = PauseThreshold.natural,
    this.isOpen = false,
  });

  /// Text already committed as captions in this session.
  final String committedText;

  /// Finalised text accumulated *within* the current utterance.
  ///
  /// Accumulated, never replaced: the recogniser clears its own buffer after
  /// each final, so replacing this drops the previous sentence (B3).
  final String pendingFinal;

  /// The latest unstable text.
  final String partial;

  /// The silence rule in force.
  final PauseThreshold threshold;

  /// Whether the microphone is open for this turn.
  final bool isOpen;

  /// The text a caption would carry if committed right now.
  String get draft => _join(pendingFinal, partial);

  /// Whether there is anything worth committing.
  bool get hasDraft => draft.trim().isNotEmpty;

  /// A copy with the given fields replaced.
  TurnState copyWith({
    String? committedText,
    String? pendingFinal,
    String? partial,
    PauseThreshold? threshold,
    bool? isOpen,
  }) => TurnState(
    committedText: committedText ?? this.committedText,
    pendingFinal: pendingFinal ?? this.pendingFinal,
    partial: partial ?? this.partial,
    threshold: threshold ?? this.threshold,
    isOpen: isOpen ?? this.isOpen,
  );

  @override
  bool operator ==(Object other) =>
      other is TurnState &&
      other.committedText == committedText &&
      other.pendingFinal == pendingFinal &&
      other.partial == partial &&
      other.threshold == threshold &&
      other.isOpen == isOpen;

  @override
  int get hashCode =>
      Object.hash(committedText, pendingFinal, partial, threshold, isOpen);

  @override
  String toString() =>
      'TurnState(open: $isOpen, final: "$pendingFinal", partial: "$partial")';
}

/// Something that happened to a turn.
sealed class TurnSignal {
  const TurnSignal();
}

/// The microphone opened.
final class TurnStarted extends TurnSignal {
  /// Creates a start signal.
  const TurnStarted();
}

/// Unstable text arrived.
final class PartialReceived extends TurnSignal {
  /// Creates a partial signal.
  const PartialReceived(this.text);

  /// The unstable text.
  final String text;
}

/// Settled text arrived.
final class FinalReceived extends TurnSignal {
  /// Creates a final signal.
  const FinalReceived(this.text);

  /// The settled text.
  final String text;
}

/// The configured silence elapsed with no speech.
final class SilenceElapsed extends TurnSignal {
  /// Creates a silence signal.
  const SilenceElapsed();
}

/// The user asked to commit now.
final class UserCommitted extends TurnSignal {
  /// Creates a manual commit signal.
  const UserCommitted();
}

/// The user closed the microphone.
final class UserStoppedTurn extends TurnSignal {
  /// Creates a turn-stop signal.
  const UserStoppedTurn();
}

/// The recogniser stopped for good.
final class RecognitionEnded extends TurnSignal {
  /// Creates a recogniser-ended signal.
  const RecognitionEnded();
}

/// What the caller should do, and the state to keep.
final class TurnDecision {
  /// Creates a decision.
  const TurnDecision({
    required this.state,
    this.commit,
    this.closeMicrophone = false,
    this.restartSilenceTimer = false,
    this.cancelSilenceTimer = false,
  });

  /// The state after this signal.
  final TurnState state;

  /// Text to commit as a caption, when the signal produced one.
  final String? commit;

  /// Whether the microphone should close.
  ///
  /// A pause never sets this. "Utterance ended" and "session ended" are
  /// different events with different handlers (B2).
  final bool closeMicrophone;

  /// Whether the silence timer should be (re)armed.
  final bool restartSilenceTimer;

  /// Whether the silence timer should be cancelled.
  final bool cancelSilenceTimer;

  /// Whether anything is being committed.
  bool get commits => commit != null;

  @override
  String toString() => 'TurnDecision(commit: $commit, close: $closeMicrophone)';
}

/// The whole of turn segmentation.
///
/// Pure: same inputs, same outputs, no clock, no plugin, no globals.
TurnDecision decideTurn(TurnState state, TurnSignal signal) {
  switch (signal) {
    case TurnStarted():
      return TurnDecision(
        state: state.copyWith(pendingFinal: '', partial: '', isOpen: true),
        restartSilenceTimer: state.threshold.commitsOnSilence,
      );

    case PartialReceived(:final String text):
      final String cleaned = text.trim();
      return TurnDecision(
        state: state.copyWith(partial: cleaned),
        // Speech restarts the clock: a pause is measured from the last sound.
        restartSilenceTimer:
            cleaned.isNotEmpty && state.threshold.commitsOnSilence,
        cancelSilenceTimer: cleaned.isEmpty,
      );

    case FinalReceived(:final String text):
      final String cleaned = text.trim();
      if (cleaned.isEmpty) {
        return TurnDecision(state: state.copyWith(partial: ''));
      }
      return TurnDecision(
        state: state.copyWith(
          // Accumulate. Never replace.
          pendingFinal: _join(state.pendingFinal, cleaned),
          partial: '',
        ),
        restartSilenceTimer: state.threshold.commitsOnSilence,
      );

    case SilenceElapsed():
      if (!state.hasDraft) {
        // Nothing to commit, but the microphone stays open and the clock keeps
        // running: silence is not the end of the session.
        return TurnDecision(
          state: state,
          restartSilenceTimer: state.threshold.commitsOnSilence,
        );
      }
      return TurnDecision(
        state: state.copyWith(
          committedText: _join(state.committedText, state.draft),
          pendingFinal: '',
          partial: '',
        ),
        commit: state.draft,
        restartSilenceTimer: state.threshold.commitsOnSilence,
      );

    case UserCommitted():
      if (!state.hasDraft) {
        return TurnDecision(state: state);
      }
      return TurnDecision(
        state: state.copyWith(
          committedText: _join(state.committedText, state.draft),
          pendingFinal: '',
          partial: '',
        ),
        commit: state.draft,
        restartSilenceTimer: state.threshold.commitsOnSilence,
      );

    case UserStoppedTurn():
    case RecognitionEnded():
      // Whatever was heard is kept. Losing recognised speech is the worst bug
      // this app can have (docs/instructions.md §1.4).
      final String? pending = state.hasDraft ? state.draft : null;
      return TurnDecision(
        state: state.copyWith(
          committedText: pending == null
              ? state.committedText
              : _join(state.committedText, pending),
          pendingFinal: '',
          partial: '',
          isOpen: false,
        ),
        commit: pending,
        closeMicrophone: true,
        cancelSilenceTimer: true,
      );
  }
}

String _join(String left, String right) {
  final String a = left.trim();
  final String b = right.trim();
  if (a.isEmpty) return b;
  if (b.isEmpty) return a;
  return '$a $b';
}
