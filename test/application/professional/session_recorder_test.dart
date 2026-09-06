import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/application/professional/session_recorder.dart';
import 'package:humsukhan/core/failure/failure.dart';
import 'package:humsukhan/domain/conversation/caption.dart';
import 'package:humsukhan/domain/professional/professional_session.dart';
import 'package:humsukhan/domain/speech/language_tag.dart';
import 'package:humsukhan/domain/speech/speech_failure.dart';
import 'package:humsukhan/domain/speech/stt_event.dart';
import 'package:humsukhan/domain/speech/stt_port.dart';

import '../../fakes/fake_speech_ports.dart';

void main() {
  late FakeSttPort stt;
  late FakeClock clock;
  late SessionRecorder recorder;

  setUp(() {
    stt = FakeSttPort();
    clock = FakeClock();
    recorder = SessionRecorder(
      stt: stt,
      ids: FakeIdGenerator(prefix: 's'),
      clock: clock,
    );
  });

  tearDown(() async => recorder.dispose());

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  Future<void> startRecording() => recorder.start(
    title: 'Standup',
    type: SessionType.meeting,
    language: LanguageTag.english,
    retentionDays: 7,
  );

  group('interim text never reaches the transcript', () {
    test('a partial is consumed without becoming a caption', () async {
      await startRecording();

      stt.partial('half a sen');
      await settle();

      expect(recorder.state.session!.captions, isEmpty);
      expect(recorder.state.hasSpeechInFlight, isTrue);
    });

    test('only the final becomes a caption', () async {
      await startRecording();

      stt.partial('the budget is');
      await settle();
      stt.finalResult('the budget is approved');
      await settle();

      expect(
        recorder.state.session!.captions.map((Caption c) => c.text),
        <String>['the budget is approved'],
      );
      expect(recorder.state.hasSpeechInFlight, isFalse);
    });

    test('the state exposes no interim text at all', () async {
      await startRecording();
      stt.partial('secret draft');
      await settle();

      // hasSpeechInFlight is a flag, not text: there is nothing to leak.
      expect(recorder.state.session!.transcriptText, isEmpty);
    });
  });

  group('a long session survives a transport drop', () {
    test('reconnecting is rendered and capture resumes', () async {
      await startRecording();
      stt.finalResult('before the drop');
      await settle();

      stt.emit(const SttReconnecting(1));
      await settle();
      expect(recorder.state.phase, RecorderPhase.reconnecting);
      expect(recorder.state.reconnectAttempt, 1);

      stt.emit(const SttReconnected());
      await settle();
      expect(recorder.state.phase, RecorderPhase.recording);

      stt.finalResult('after the drop');
      await settle();
      expect(
        recorder.state.session!.captions.map((Caption c) => c.text),
        <String>['before the drop', 'after the drop'],
      );
    });

    test('a failure keeps everything captured so far', () async {
      await startRecording();
      stt.finalResult('forty minutes of lecture');
      await settle();

      stt.emit(const SttFailed(SttFailure(FailureCode.sttTransportLost)));
      await settle();

      expect(recorder.state.phase, RecorderPhase.failed);
      expect(recorder.state.failure, isNotNull);
      expect(recorder.state.session!.captions.length, 1);
      expect(recorder.state.session!.endedAt, isNotNull);
    });

    test(
      'a silent stream close fails rather than looking like recording',
      () async {
        await startRecording();
        await stt.closeSilently();
        await settle();

        expect(recorder.state.phase, RecorderPhase.failed);
      },
    );
  });

  group('start and stop', () {
    test('recording asks for the dictation profile', () async {
      await startRecording();
      expect(stt.startRequests.single.profile, SttProfile.dictation);
    });

    test(
      'a second start while starting does not open a second recogniser',
      () async {
        stt.startDelay = const Duration(milliseconds: 30);
        final Future<void> first = startRecording();
        final Future<void> second = startRecording();
        await Future.wait<void>(<Future<void>>[first, second]);

        expect(stt.startRequests.length, 1);
      },
    );

    test('a start failure is visible with a reason', () async {
      stt.failOnStart = const SttFailure(FailureCode.microphoneUnavailable);
      await startRecording();

      expect(recorder.state.phase, RecorderPhase.failed);
      expect(recorder.state.failure?.code, FailureCode.microphoneUnavailable);
      expect(recorder.state.failure?.remedy, isNotNull);
    });

    test('stopping stamps the end time and keeps the transcript', () async {
      await startRecording();
      stt.finalResult('one line');
      await settle();
      await recorder.stop();

      expect(recorder.state.phase, RecorderPhase.stopped);
      expect(recorder.state.session!.endedAt, isNotNull);
      expect(recorder.state.session!.captions.length, 1);
      expect(stt.stopCount, 1);
    });

    test('discarding returns to idle with no session', () async {
      await startRecording();
      recorder.discard();

      expect(recorder.state.phase, RecorderPhase.idle);
      expect(recorder.state.session, isNull);
    });
  });

  group('manual captions', () {
    test('a typed line is added as the user speaking', () async {
      await startRecording();
      recorder.addManualCaption('I will send the notes');

      expect(
        recorder.state.session!.captions.single.speaker,
        CaptionSpeaker.own,
      );
    });

    test('Roman Urdu is normalised before it enters the transcript', () async {
      await startRecording();
      recorder.addManualCaption('main kal aaunga');

      expect(
        recorder.state.session!.captions.single.text,
        isNot(contains('main')),
      );
    });

    test('an empty line is not added', () async {
      await startRecording();
      recorder.addManualCaption('   ');

      expect(recorder.state.session!.captions, isEmpty);
    });
  });

  group('after dispose', () {
    test('events change nothing', () async {
      await startRecording();
      await recorder.dispose();

      stt.finalResult('too late');
      await settle();

      expect(recorder.state.session!.captions, isEmpty);
    });
  });

  group('pausing a long session', () {
    Future<void> begin() => recorder.start(
      title: 'Physics lecture',
      type: SessionType.lecture,
      language: LanguageTag.english,
      retentionDays: 7,
    );

    test(
      'pausing releases the microphone and keeps the session open',
      () async {
        await begin();

        await recorder.pause();

        expect(recorder.state.phase, RecorderPhase.paused);
        // Still open, so the transcript carries on into the same session — that
        // is the whole difference between pausing and stopping.
        expect(recorder.state.isActive, isTrue);
        expect(recorder.state.session, isNotNull);
        expect(stt.stopCount, 1);
      },
    );

    test('what was already said is kept across a pause', () async {
      await begin();
      stt.finalResult('the first half');
      await Future<void>.delayed(Duration.zero);

      await recorder.pause();

      expect(recorder.state.session!.captions.single.text, 'the first half');
    });

    test('resuming continues the same transcript, not a new session', () async {
      await begin();
      stt.finalResult('before the break');
      await Future<void>.delayed(Duration.zero);
      final String id = recorder.state.session!.id;

      await recorder.pause();
      await recorder.resume();
      stt.finalResult('after the break');
      await Future<void>.delayed(Duration.zero);

      expect(recorder.state.phase, RecorderPhase.recording);
      expect(recorder.state.session!.id, id);
      expect(
        recorder.state.session!.captions.map((Caption c) => c.text),
        <String>['before the break', 'after the break'],
      );
    });

    test('time spent paused is not counted as recorded time', () async {
      await begin();
      clock.advance(const Duration(minutes: 10));

      await recorder.pause();
      clock.advance(const Duration(minutes: 30));
      await recorder.resume();
      clock.advance(const Duration(minutes: 5));

      // Forty-five minutes of wall clock, fifteen of recording. Reading back a
      // forty-five minute lecture that was recorded for fifteen is simply
      // wrong, and the user has no way to tell it is wrong.
      expect(recorder.durationAt(clock.now()), const Duration(minutes: 15));
    });

    test('the readout freezes while paused rather than ticking on', () async {
      await begin();
      clock.advance(const Duration(minutes: 2));
      await recorder.pause();

      final Duration atPause = recorder.durationAt(clock.now());
      clock.advance(const Duration(minutes: 20));

      expect(recorder.durationAt(clock.now()), atPause);
    });

    test('a late transport event does not undo the pause', () async {
      await begin();
      await recorder.pause();

      // The engine reports its own end after we asked it to stop.
      stt.emit(const SttEnded(SttEndReason.stoppedByUser));
      await Future<void>.delayed(Duration.zero);

      expect(recorder.state.phase, RecorderPhase.paused);
    });

    test('speech arriving while paused is not appended', () async {
      await begin();
      await recorder.pause();

      stt.finalResult('nobody should hear this');
      await Future<void>.delayed(Duration.zero);

      expect(recorder.state.session!.captions, isEmpty);
    });

    test('a note can still be typed during a break', () async {
      await begin();
      await recorder.pause();

      recorder.addManualCaption('remember to ask about the deadline');

      expect(recorder.state.session!.captions, hasLength(1));
    });

    test('stopping from paused finishes the session', () async {
      await begin();
      await recorder.pause();

      await recorder.stop();

      expect(recorder.state.phase, RecorderPhase.stopped);
      expect(recorder.state.session!.endedAt, isNotNull);
    });

    test('pause and resume are offered only when they would work', () async {
      expect(recorder.state.canPause, isFalse);
      expect(recorder.state.canResume, isFalse);

      await begin();
      expect(recorder.state.canPause, isTrue);
      expect(recorder.state.canResume, isFalse);

      await recorder.pause();
      expect(recorder.state.canPause, isFalse);
      expect(recorder.state.canResume, isTrue);
    });

    test(
      'resuming when not paused fails rather than doing something odd',
      () async {
        await begin();

        expect((await recorder.resume()).isErr, isTrue);
        expect(recorder.state.phase, RecorderPhase.recording);
      },
    );

    test('pausing when not recording is a no-op', () async {
      await recorder.pause();

      expect(recorder.state.phase, RecorderPhase.idle);
      expect(stt.stopCount, 0);
    });

    test(
      'a failed resume says so and leaves the session recoverable',
      () async {
        await begin();
        await recorder.pause();
        stt.failOnStart = const SttFailure(FailureCode.microphoneUnavailable);

        final result = await recorder.resume();

        expect(result.isErr, isTrue);
        // The transcript is still there to be saved; a failed resume must not
        // cost the user the half of the lecture they already have.
        expect(recorder.state.session, isNotNull);
      },
    );

    test('a new session clears the previous pause accounting', () async {
      await begin();
      clock.advance(const Duration(minutes: 5));
      await recorder.pause();
      clock.advance(const Duration(minutes: 20));
      await recorder.stop();

      recorder.discard();
      await begin();
      clock.advance(const Duration(minutes: 3));

      expect(recorder.durationAt(clock.now()), const Duration(minutes: 3));
    });
  });
}
