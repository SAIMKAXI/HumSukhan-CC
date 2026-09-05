import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/domain/conversation/turn_policy.dart';

void main() {
  group('B2 — a pause ends an utterance, not the session', () {
    test('silence commits the draft and leaves the microphone open', () {
      const TurnState state = TurnState(
        pendingFinal: 'where is the room',
        isOpen: true,
      );

      final TurnDecision decision = decideTurn(state, const SilenceElapsed());

      expect(decision.commit, 'where is the room');
      expect(
        decision.closeMicrophone,
        isFalse,
        reason: 'silence must never close the microphone',
      );
      expect(decision.state.isOpen, isTrue);
    });

    test('the silence timer is re-armed after a commit, so the next '
        'utterance is also segmented', () {
      const TurnState state = TurnState(pendingFinal: 'hello', isOpen: true);

      final TurnDecision decision = decideTurn(state, const SilenceElapsed());

      expect(decision.restartSilenceTimer, isTrue);
    });

    test('silence with nothing heard commits nothing and keeps listening', () {
      const TurnState state = TurnState(isOpen: true);

      final TurnDecision decision = decideTurn(state, const SilenceElapsed());

      expect(decision.commits, isFalse);
      expect(decision.closeMicrophone, isFalse);
      expect(decision.restartSilenceTimer, isTrue);
    });

    test('only the user closes the microphone', () {
      const TurnState state = TurnState(pendingFinal: 'hello', isOpen: true);

      expect(
        decideTurn(state, const UserStoppedTurn()).closeMicrophone,
        isTrue,
      );
    });

    test('manual threshold never arms the timer', () {
      const TurnState state = TurnState(
        threshold: PauseThreshold.manual,
        isOpen: true,
      );

      final TurnDecision decision =
          decideTurn(state, const PartialReceived('hello'));

      expect(decision.restartSilenceTimer, isFalse);
    });
  });

  group('B3 — finals accumulate within a turn, never overwrite', () {
    test('a second final is appended to the first', () {
      const TurnState state = TurnState(isOpen: true);

      final TurnDecision first =
          decideTurn(state, const FinalReceived('where is'));
      final TurnDecision second =
          decideTurn(first.state, const FinalReceived('the meeting room'));

      expect(second.state.pendingFinal, 'where is the meeting room');
    });

    test('three rapid finals all survive', () {
      TurnState state = const TurnState(isOpen: true);
      for (final String piece in <String>['one', 'two', 'three']) {
        state = decideTurn(state, FinalReceived(piece)).state;
      }
      expect(state.pendingFinal, 'one two three');
    });

    test('a partial after a final does not erase the final', () {
      const TurnState state = TurnState(pendingFinal: 'first sentence', isOpen: true);

      final TurnDecision decision =
          decideTurn(state, const PartialReceived('second'));

      expect(decision.state.pendingFinal, 'first sentence');
      expect(decision.state.draft, 'first sentence second');
    });

    test('committing clears only the pending buffer, keeping the history', () {
      const TurnState state = TurnState(
        committedText: 'earlier caption',
        pendingFinal: 'new sentence',
        isOpen: true,
      );

      final TurnDecision decision = decideTurn(state, const SilenceElapsed());

      expect(decision.state.pendingFinal, isEmpty);
      expect(decision.state.committedText, 'earlier caption new sentence');
    });

    test('an empty final is ignored rather than committed', () {
      const TurnState state = TurnState(pendingFinal: 'kept', isOpen: true);

      final TurnDecision decision = decideTurn(state, const FinalReceived('   '));

      expect(decision.state.pendingFinal, 'kept');
    });
  });

  group('nothing recognised is ever dropped', () {
    test('stopping the turn commits whatever was in flight', () {
      const TurnState state = TurnState(
        pendingFinal: 'half a sentence',
        partial: 'and a bit more',
        isOpen: true,
      );

      final TurnDecision decision = decideTurn(state, const UserStoppedTurn());

      expect(decision.commit, 'half a sentence and a bit more');
    });

    test('the recogniser ending commits whatever was in flight', () {
      const TurnState state = TurnState(partial: 'unfinished', isOpen: true);

      final TurnDecision decision = decideTurn(state, const RecognitionEnded());

      expect(decision.commit, 'unfinished');
      expect(decision.closeMicrophone, isTrue);
    });

    test('stopping with nothing heard commits nothing', () {
      const TurnState state = TurnState(isOpen: true);

      expect(decideTurn(state, const UserStoppedTurn()).commits, isFalse);
    });
  });

  group('starting a turn', () {
    test('clears the previous turn buffers but keeps the session history', () {
      const TurnState state = TurnState(
        committedText: 'earlier',
        pendingFinal: 'stale',
        partial: 'stale',
      );

      final TurnDecision decision = decideTurn(state, const TurnStarted());

      expect(decision.state.pendingFinal, isEmpty);
      expect(decision.state.partial, isEmpty);
      expect(decision.state.committedText, 'earlier');
      expect(decision.state.isOpen, isTrue);
    });
  });

  group('manual commit', () {
    test('commits the draft and keeps listening', () {
      const TurnState state = TurnState(partial: 'said something', isOpen: true);

      final TurnDecision decision = decideTurn(state, const UserCommitted());

      expect(decision.commit, 'said something');
      expect(decision.closeMicrophone, isFalse);
    });

    test('does nothing when there is no draft', () {
      const TurnState state = TurnState(isOpen: true);

      expect(decideTurn(state, const UserCommitted()).commits, isFalse);
    });
  });

  group('PauseThreshold', () {
    test('durations match the values offered in the UI', () {
      expect(PauseThreshold.short.duration, const Duration(milliseconds: 1200));
      expect(PauseThreshold.natural.duration, const Duration(milliseconds: 1700));
      expect(PauseThreshold.patient.duration, const Duration(milliseconds: 2500));
      expect(PauseThreshold.manual.duration, isNull);
    });

    test('an unknown stored name falls back to natural', () {
      expect(PauseThreshold.fromName('nonsense'), PauseThreshold.natural);
      expect(PauseThreshold.fromName(null), PauseThreshold.natural);
      expect(PauseThreshold.fromName('patient'), PauseThreshold.patient);
    });
  });
}
