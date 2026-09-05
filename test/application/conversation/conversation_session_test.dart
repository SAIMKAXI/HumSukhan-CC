import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/application/conversation/conversation_session.dart';
import 'package:humsukhan/application/conversation/conversation_session_state.dart';
import 'package:humsukhan/core/failure/failure.dart';
import 'package:humsukhan/core/result/result.dart';
import 'package:humsukhan/domain/conversation/caption.dart';
import 'package:humsukhan/domain/conversation/turn_policy.dart';
import 'package:humsukhan/domain/speech/language_tag.dart';
import 'package:humsukhan/domain/speech/speech_failure.dart';
import 'package:humsukhan/domain/speech/stt_event.dart';

import '../../fakes/fake_speech_ports.dart';

void main() {
  late FakeSttPort stt;
  late FakeTtsPort tts;
  late FakeClock clock;
  late ConversationSession session;

  ConversationSession build({
    PauseThreshold threshold = PauseThreshold.natural,
    LanguageTag language = LanguageTag.english,
  }) {
    stt = FakeSttPort();
    tts = FakeTtsPort();
    clock = FakeClock();
    return ConversationSession(
      stt: stt,
      tts: tts,
      ids: FakeIdGenerator(prefix: 'c'),
      clock: clock,
      captionLanguage: language,
      threshold: threshold,
    );
  }

  setUp(() => session = build());
  tearDown(() async => session.dispose());

  /// Lets the fake's broadcast stream deliver.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  group('lifecycle', () {
    test('a new session is idle with the microphone closed', () {
      expect(session.state.stage, ConversationStage.idle);
      expect(session.state.phase, ListeningPhase.idle);
      expect(session.state.isMicrophoneOpen, isFalse);
    });

    test('beginning does not open the microphone', () {
      session.begin();
      expect(session.state.stage, ConversationStage.active);
      expect(stt.startRequests, isEmpty);
    });

    test('starting to listen moves through starting to listening', () async {
      session.begin();
      final Future<Result<Unit, SttFailure>> pending = session.startListening();
      expect(session.state.phase, ListeningPhase.starting);
      await pending;
      expect(session.state.phase, ListeningPhase.listening);
      expect(stt.startRequests.single.language, LanguageTag.english);
    });

    test('stopping the conversation asks for a save decision', () async {
      session.begin();
      await session.startListening();
      await session.stop();
      expect(session.state.stage, ConversationStage.saveDecision);
      expect(session.state.phase, ListeningPhase.idle);
    });

    test('continuing returns to an active conversation', () async {
      session.begin();
      await session.stop();
      session.resume();
      expect(session.state.stage, ConversationStage.active);
    });
  });

  group('B10 — two rapid taps open one microphone session', () {
    test('a second start while the first is in flight is ignored', () async {
      session = build();
      stt.startDelay = const Duration(milliseconds: 30);
      session.begin();

      final Future<Result<Unit, SttFailure>> first = session.startListening();
      final Future<Result<Unit, SttFailure>> second = session.startListening();
      await Future.wait<Result<Unit, SttFailure>>(
        <Future<Result<Unit, SttFailure>>>[first, second],
      );

      expect(stt.startRequests.length, 1);
    });

    test('stopping during a slow start supersedes it', () async {
      session = build();
      stt.startDelay = const Duration(milliseconds: 40);
      session.begin();

      final Future<Result<Unit, SttFailure>> starting = session
          .startListening();
      await session.stopListening();
      await starting;

      expect(
        session.state.phase,
        ListeningPhase.idle,
        reason: 'a superseded start must not claim the session',
      );
    });
  });

  group('B2 — a pause commits an utterance, the microphone stays open', () {
    test('the silence timer commits a caption and keeps listening', () async {
      session = build(threshold: PauseThreshold.short);
      session.begin();
      await session.startListening();

      stt.finalResult('where is the meeting room');
      await settle();
      // The configured pause is 1.2s; wait past it.
      await Future<void>.delayed(const Duration(milliseconds: 1400));

      expect(session.state.captions.single.text, 'where is the meeting room');
      expect(session.state.isMicrophoneOpen, isTrue);
      expect(stt.stopCount, 0, reason: 'a pause must not stop the recogniser');
    });

    test('two utterances become two captions without re-tapping', () async {
      session = build(threshold: PauseThreshold.short);
      session.begin();
      await session.startListening();

      stt.finalResult('first sentence');
      await settle();
      await Future<void>.delayed(const Duration(milliseconds: 1400));
      stt.finalResult('second sentence');
      await settle();
      await Future<void>.delayed(const Duration(milliseconds: 1400));

      expect(session.state.captions.map((Caption c) => c.text), <String>[
        'first sentence',
        'second sentence',
      ]);
      expect(session.state.isMicrophoneOpen, isTrue);
    });
  });

  group('B3 — finalised text accumulates within a turn', () {
    test(
      'two finals before the pause become one caption, not one lost',
      () async {
        session = build(threshold: PauseThreshold.patient);
        session.begin();
        await session.startListening();

        stt.finalResult('where is');
        await settle();
        stt.finalResult('the meeting room');
        await settle();
        session.commitNow();

        expect(session.state.captions.single.text, 'where is the meeting room');
      },
    );

    test('a partial never erases an earlier final', () async {
      session.begin();
      await session.startListening();

      stt.finalResult('first');
      await settle();
      stt.partial('second');
      await settle();

      expect(session.state.partialText, 'first second');
    });
  });

  group('B1 — captions come only from this session', () {
    test('each committed caption carries its own text and id', () async {
      session = build(threshold: PauseThreshold.manual);
      session.begin();
      await session.startListening();

      stt.finalResult('first phrase');
      await settle();
      session.commitNow();
      stt.finalResult('second phrase');
      await settle();
      session.commitNow();

      final List<Caption> captions = session.state.captions;
      expect(captions.map((Caption c) => c.text), <String>[
        'first phrase',
        'second phrase',
      ], reason: 'a caption must never be overwritten by an earlier value');
      expect(captions[0].id, isNot(captions[1].id));
    });

    test('identical captions remain distinct entries', () async {
      session = build(threshold: PauseThreshold.manual);
      session.begin();
      await session.startListening();

      for (int i = 0; i < 2; i++) {
        stt.finalResult('yes');
        await settle();
        session.commitNow();
      }

      expect(session.state.captions.length, 2);
      expect(session.state.captions[0].id, isNot(session.state.captions[1].id));
    });
  });

  group('B4 — a dead stream is visible', () {
    test('a failure event surfaces as a failed phase with a reason', () async {
      session.begin();
      await session.startListening();

      stt.emit(const SttFailed(SttFailure(FailureCode.sttTransportLost)));
      await settle();

      expect(session.state.phase, ListeningPhase.failed);
      expect(session.state.failure?.code, FailureCode.sttTransportLost);
      expect(session.state.failure?.remedy, isNotNull);
    });

    test(
      'a stream that closes with no terminal event still fails loudly',
      () async {
        session.begin();
        await session.startListening();

        await stt.closeSilently();
        await settle();

        expect(
          session.state.phase,
          ListeningPhase.failed,
          reason: 'a silent close must not leave the UI reading "Listening…"',
        );
        expect(session.state.failure, isNotNull);
      },
    );

    test('a raw stream error surfaces rather than reaching the zone', () async {
      session.begin();
      await session.startListening();

      stt.emitStreamError(StateError('socket died'));
      await settle();

      expect(session.state.phase, ListeningPhase.failed);
    });

    test('an unexpected end is a failure, an asked-for end is not', () async {
      session.begin();
      await session.startListening();
      stt.emit(const SttEnded(SttEndReason.closedByService));
      await settle();
      expect(session.state.phase, ListeningPhase.failed);

      session.acknowledgeFailure();
      await session.startListening();
      await session.stopListening();
      stt.emit(const SttEnded(SttEndReason.stoppedByUser));
      await settle();
      expect(session.state.phase, ListeningPhase.idle);
      expect(session.state.failure, isNull);
    });

    test('speech heard before the transport died is kept', () async {
      session = build(threshold: PauseThreshold.patient);
      session.begin();
      await session.startListening();

      stt.finalResult('important sentence');
      await settle();
      stt.emit(const SttFailed(SttFailure(FailureCode.sttTransportLost)));
      await settle();

      expect(
        session.state.captions.single.text,
        'important sentence',
        reason: 'losing recognised speech is the worst bug this app can have',
      );
    });
  });

  group('reconnecting is a rendered state', () {
    test('reconnect events move the phase and back again', () async {
      session.begin();
      await session.startListening();

      stt.emit(const SttReconnecting(1));
      await settle();
      expect(session.state.phase, ListeningPhase.reconnecting);
      expect(session.state.reconnectAttempt, 1);

      stt.emit(const SttReconnected());
      await settle();
      expect(session.state.phase, ListeningPhase.listening);
      expect(session.state.reconnectAttempt, 0);
    });
  });

  group('B7/B8 — every action ends in a visible outcome', () {
    test('a start failure is both returned and reflected in state', () async {
      session = build();
      stt.failOnStart = const SttFailure(FailureCode.sttStartFailed);
      session.begin();

      final Result<Unit, SttFailure> result = await session.startListening();

      expect(result.isErr, isTrue);
      expect(session.state.phase, ListeningPhase.failed);
      expect(session.state.failure?.code, FailureCode.sttStartFailed);
    });

    test('a speak failure is returned rather than thrown', () async {
      tts.failOnSpeak = const TtsFailure(FailureCode.ttsVoiceMissing);

      final Result<Unit, TtsFailure> result = await session.speak('hello');

      expect(result.isErr, isTrue);
      expect(result.errorOrNull?.code, FailureCode.ttsVoiceMissing);
    });

    test(
      'speaking empty text fails rather than silently doing nothing',
      () async {
        final Result<Unit, TtsFailure> result = await session.speak('   ');
        expect(result.isErr, isTrue);
        expect(tts.spoken, isEmpty);
      },
    );

    test('the busy flag clears after speaking, success or failure', () async {
      tts.failOnSpeak = const TtsFailure(FailureCode.ttsFailed);
      await session.speak('hello');
      expect(session.state.isBusy, isFalse);
    });
  });

  group('speaking is tracked by caption id, not by text', () {
    test('two identical captions do not both show as speaking', () async {
      tts.speakDuration = const Duration(milliseconds: 20);
      session.begin();
      final Caption? first = session.sendTyped('yes');
      final Caption? second = session.sendTyped('yes');
      expect(first!.id, isNot(second!.id));

      final Future<Result<Unit, TtsFailure>> speaking = session.speak(
        'yes',
        captionId: first.id,
      );
      expect(session.state.speakingCaptionId, first.id);
      expect(session.state.speakingCaptionId, isNot(second.id));
      await speaking;
    });
  });

  group('typed replies', () {
    test('a typed reply becomes an own caption', () {
      session.begin();
      final Caption? caption = session.sendTyped('I am here');
      expect(caption, isNotNull);
      expect(session.state.captions.single.speaker, CaptionSpeaker.own);
    });

    test('Roman Urdu is normalised to Urdu script before storage', () {
      session.begin();
      final Caption? caption = session.sendTyped('aap kaise hain');
      expect(caption!.text, 'آپ کیسے ہیں');
    });

    test('Devanagari is stripped before it is ever stored', () {
      session.begin();
      final Caption? caption = session.sendTyped('hello मीटिंग there');
      expect(caption!.text, 'hello there');
    });

    test('an empty reply is not stored', () {
      session.begin();
      expect(session.sendTyped('   '), isNull);
      expect(session.state.captions, isEmpty);
    });
  });

  group('language routing', () {
    test('Urdu text is spoken in Urdu even in an English session', () async {
      await session.speak('السلام علیکم');
      expect(tts.spoken.single.language, LanguageTag.urdu);
    });

    test('English text is spoken in English', () async {
      await session.speak('good morning');
      expect(tts.spoken.single.language, LanguageTag.english);
    });
  });

  group('B15 — nothing is touched after dispose', () {
    test('events after dispose change nothing and do not throw', () async {
      session.begin();
      await session.startListening();
      await session.dispose();

      stt.finalResult('too late');
      await settle();

      expect(session.state.captions, isEmpty);
    });

    test('speaking after dispose fails instead of throwing', () async {
      await session.dispose();
      final Result<Unit, TtsFailure> result = await session.speak('hello');
      expect(result.isErr, isTrue);
    });
  });

  group('pause threshold', () {
    test('manual never commits on silence', () async {
      session = build(threshold: PauseThreshold.manual);
      session.begin();
      await session.startListening();

      stt.finalResult('kept in the draft');
      await settle();
      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(session.state.captions, isEmpty);
      expect(session.state.partialText, 'kept in the draft');
    });

    test('changing the threshold mid-session takes effect', () async {
      session = build(threshold: PauseThreshold.manual);
      session.begin();
      await session.startListening();
      session.setThreshold(PauseThreshold.short);

      stt.finalResult('now committed');
      await settle();
      await Future<void>.delayed(const Duration(milliseconds: 1400));

      expect(session.state.captions.single.text, 'now committed');
    });
  });

  group('saving', () {
    test('the saved conversation carries every caption', () async {
      session.begin();
      session.sendTyped('one');
      session.sendTyped('two');
      await session.stop();

      expect(session.toConversation().captions.length, 2);
    });

    test('reset clears the conversation', () async {
      session.begin();
      session.sendTyped('one');
      session.reset();

      expect(session.state.captions, isEmpty);
      expect(session.state.stage, ConversationStage.idle);
    });
  });
}
