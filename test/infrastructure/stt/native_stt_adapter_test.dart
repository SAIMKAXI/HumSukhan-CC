import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/core/failure/failure.dart';
import 'package:humsukhan/core/result/result.dart';
import 'package:humsukhan/domain/speech/language_tag.dart';
import 'package:humsukhan/domain/speech/speech_failure.dart';
import 'package:humsukhan/domain/speech/stt_event.dart';
import 'package:humsukhan/domain/speech/stt_port.dart';
import 'package:humsukhan/infrastructure/audio/microphone_source.dart';
import 'package:humsukhan/infrastructure/stt/native_stt_adapter.dart';
import 'package:humsukhan/infrastructure/stt/platform_recogniser.dart';

/// A recogniser the test drives directly, with no device behind it.
///
/// The whole reason [PlatformRecogniser] exists: the restart-across-silence
/// logic is the part most likely to be wrong and the part hardest to reach on
/// real hardware, so it is exercised here instead.
class _FakeRecogniser implements PlatformRecogniser {
  Set<String> locales = <String>{'en-us', 'ur-pk'};
  bool available = true;
  bool initialises = true;

  /// Locales for which an on-device listen is refused, as a real engine does
  /// when it has no offline model.
  Set<String> refusesOnDevice = <String>{};

  int listens = 0;
  int stops = 0;
  int cancels = 0;
  final List<bool> onDeviceRequests = <bool>[];
  String? lastLocale;

  void Function(RecogniserError error)? _onError;
  void Function(String status)? _onStatus;
  void Function(RecognisedSpeech result)? _onResult;

  @override
  Future<bool> initialise({
    required void Function(RecogniserError error) onError,
    required void Function(String status) onStatus,
  }) async {
    _onError = onError;
    _onStatus = onStatus;
    return initialises;
  }

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<Set<String>> localeIds() async => locales;

  @override
  Future<void> listen({
    required String localeId,
    required bool partialResults,
    required bool onDevice,
    required bool punctuate,
    required bool dictation,
    required Duration pauseFor,
    required Duration listenFor,
    required void Function(RecognisedSpeech result) onResult,
  }) async {
    onDeviceRequests.add(onDevice);
    if (onDevice && refusesOnDevice.contains(localeId)) {
      throw StateError('no offline model for $localeId');
    }
    listens++;
    lastLocale = localeId;
    _onResult = onResult;
  }

  @override
  Future<void> stop() async => stops++;

  @override
  Future<void> cancel() async => cancels++;

  // ---- test drivers ----

  void emitPartial(String text) =>
      _onResult?.call(RecognisedSpeech(text: text, isFinal: false));

  void emitFinal(String text, {double? confidence}) => _onResult?.call(
    RecognisedSpeech(text: text, isFinal: true, confidence: confidence),
  );

  void emitStatus(String status) => _onStatus?.call(status);

  void emitError(String code, {bool permanent = false}) =>
      _onError?.call(RecogniserError(code, permanent: permanent));
}

/// The microphone permission answer, under the test's control.
class _FakePermission implements MicrophonePermission {
  AudioFailure? refusal;
  int asks = 0;

  @override
  Future<Result<Unit, AudioFailure>> ensurePermission() async {
    asks++;
    final AudioFailure? denied = refusal;
    return denied == null
        ? const Ok<Unit, AudioFailure>(unit)
        : Err<Unit, AudioFailure>(denied);
  }
}

void main() {
  late _FakeRecogniser recogniser;
  late _FakePermission permission;
  late NativeSttAdapter adapter;

  setUp(() {
    recogniser = _FakeRecogniser();
    permission = _FakePermission();
    adapter = NativeSttAdapter(
      recogniser: recogniser,
      permissions: permission,
      restartDelay: Duration.zero,
    );
  });

  tearDown(() => adapter.dispose());

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  group('starting', () {
    test(
      'a supported language starts and reports the resolved locale',
      () async {
        final Result<Unit, SttFailure> result = await adapter.start(
          const SttRequest(language: LanguageTag.urdu),
        );

        expect(result.isOk, isTrue);
        expect(recogniser.lastLocale, 'ur-pk');
      },
    );

    test('a regional variant satisfies the language', () async {
      recogniser.locales = <String>{'en-gb'};

      expect(
        (await adapter.start(const SttRequest(language: LanguageTag.english)))
            .isOk,
        isTrue,
      );
      expect(recogniser.lastLocale, 'en-gb');
    });

    test(
      'a missing language fails with the code the install flow keys on',
      () async {
        recogniser.locales = <String>{'en-us'};

        final Result<Unit, SttFailure> result = await adapter.start(
          const SttRequest(language: LanguageTag.urdu),
        );

        expect(result.isErr, isTrue);
        // Recoverable: installing the pack is exactly how the user recovers.
        expect(result.errorOrNull!.code, FailureCode.sttLanguageUnsupported);
        expect(result.errorOrNull!.isRecoverable, isTrue);
      },
    );

    test('English is never substituted for a missing Urdu model', () async {
      recogniser.locales = <String>{'en-us', 'en-gb', 'en-in'};

      final Result<Unit, SttFailure> result = await adapter.start(
        const SttRequest(language: LanguageTag.urdu),
      );

      expect(result.isErr, isTrue);
      expect(recogniser.listens, 0);
    });

    test('a refused microphone says so, not "recognition failed"', () async {
      permission.refusal = const AudioFailure(
        FailureCode.microphonePermissionDenied,
      );

      final Result<Unit, SttFailure> result = await adapter.start(
        const SttRequest(language: LanguageTag.english),
      );

      // "Recognition could not start. Try starting again." is useless to
      // someone whose microphone is blocked; this is the one they can act on.
      expect(result.errorOrNull!.code, FailureCode.microphonePermissionDenied);
      expect(result.errorOrNull!.isRecoverable, isTrue);
      // The engine is never touched when the answer is already no.
      expect(recogniser.listens, 0);
    });

    test('a permanently blocked microphone is not offered a retry', () async {
      permission.refusal = const AudioFailure(
        FailureCode.microphonePermissionPermanentlyDenied,
        isRecoverable: false,
      );

      final Result<Unit, SttFailure> result = await adapter.start(
        const SttRequest(language: LanguageTag.english),
      );

      expect(
        result.errorOrNull!.code,
        FailureCode.microphonePermissionPermanentlyDenied,
      );
      expect(result.errorOrNull!.isRecoverable, isFalse);
    });

    test('permission is asked before the engine is prepared', () async {
      await adapter.start(const SttRequest(language: LanguageTag.english));

      expect(permission.asks, 1);
    });

    test('no recogniser at all fails as unrecoverable', () async {
      recogniser.initialises = false;

      final Result<Unit, SttFailure> result = await adapter.start(
        const SttRequest(language: LanguageTag.english),
      );

      expect(result.errorOrNull!.code, FailureCode.sttStartFailed);
      expect(result.errorOrNull!.isRecoverable, isFalse);
    });

    test(
      'on-device is asked for first, and refusal is not a failure',
      () async {
        recogniser.refusesOnDevice = <String>{'en-us'};

        final Result<Unit, SttFailure> result = await adapter.start(
          const SttRequest(language: LanguageTag.english),
        );

        // On-device is tried first and, when the engine has no offline model,
        // the same listen is retried letting the engine choose. Captions that
        // work over the network beat no captions at all.
        expect(result.isOk, isTrue);
        expect(recogniser.onDeviceRequests, <bool>[true, false]);
      },
    );
  });

  group('a pause is not the end of the session', () {
    test('a finished segment restarts instead of ending', () async {
      await adapter.start(const SttRequest(language: LanguageTag.english));
      final List<SttEvent> seen = <SttEvent>[];
      adapter.events.listen(seen.add);

      // Android says this after every natural pause in speech.
      recogniser.emitStatus('done');
      await settle();

      expect(recogniser.listens, 2);
      // Ending here is the shipped bug that stopped captions after one
      // sentence. The caller must see nothing at all.
      expect(seen, isEmpty);
    });

    test('silence errors restart without a single pixel of UI', () async {
      await adapter.start(const SttRequest(language: LanguageTag.english));
      final List<SttEvent> seen = <SttEvent>[];
      adapter.events.listen(seen.add);

      recogniser.emitError('error_speech_timeout');
      await settle();
      recogniser.emitError('error_no_match');
      await settle();

      expect(recogniser.listens, 3);
      expect(seen, isEmpty);
    });

    test('speech survives across a restart', () async {
      await adapter.start(const SttRequest(language: LanguageTag.english));
      final List<SttEvent> seen = <SttEvent>[];
      adapter.events.listen(seen.add);

      recogniser.emitFinal('the first sentence');
      recogniser.emitStatus('done');
      await settle();
      recogniser.emitFinal('the second sentence');
      await settle();

      expect(seen.whereType<SttFinal>().map((SttFinal f) => f.text), <String>[
        'the first sentence',
        'the second sentence',
      ]);
    });

    test('a restart does not blank the caption being read', () async {
      await adapter.start(const SttRequest(language: LanguageTag.english));
      final List<SttEvent> seen = <SttEvent>[];
      adapter.events.listen(seen.add);

      recogniser.emitPartial('half a sen');
      recogniser.emitStatus('done');
      await settle();
      // A fresh segment opens with an empty partial. Forwarding it would wipe
      // the text mid-read.
      recogniser.emitPartial('');
      await settle();

      expect(
        seen.whereType<SttPartial>().map((SttPartial p) => p.text),
        <String>['half a sen'],
      );
    });

    test('an empty final does not append a blank turn', () async {
      await adapter.start(const SttRequest(language: LanguageTag.english));
      final List<SttEvent> seen = <SttEvent>[];
      adapter.events.listen(seen.add);

      recogniser.emitFinal('   ');
      await settle();

      expect(seen.whereType<SttFinal>(), isEmpty);
    });

    test('an unchanged partial is not re-emitted', () async {
      await adapter.start(const SttRequest(language: LanguageTag.english));
      final List<SttEvent> seen = <SttEvent>[];
      adapter.events.listen(seen.add);

      recogniser.emitPartial('hello');
      recogniser.emitPartial('hello');
      await settle();

      expect(seen.whereType<SttPartial>().length, 1);
    });
  });

  group('failures are visible and final', () {
    test('a blocked microphone fails immediately and unrecoverably', () async {
      await adapter.start(const SttRequest(language: LanguageTag.english));
      final List<SttEvent> seen = <SttEvent>[];
      adapter.events.listen(seen.add);

      recogniser.emitError('error_permission', permanent: true);
      await settle();

      final SttFailed failure = seen.whereType<SttFailed>().single;
      expect(failure.cause.code, FailureCode.microphonePermissionDenied);
      expect(failure.cause.isRecoverable, isFalse);
    });

    test('a language the engine rejects mid-session is fatal', () async {
      await adapter.start(const SttRequest(language: LanguageTag.urdu));
      final List<SttEvent> seen = <SttEvent>[];
      adapter.events.listen(seen.add);

      recogniser.emitError('error_language_not_supported', permanent: true);
      await settle();

      expect(
        seen.whereType<SttFailed>().single.cause.code,
        FailureCode.sttLanguageUnsupported,
      );
    });

    test('transient trouble reconnects visibly before giving up', () async {
      await adapter.start(const SttRequest(language: LanguageTag.english));
      final List<SttEvent> seen = <SttEvent>[];
      adapter.events.listen(seen.add);

      for (int i = 0; i < 3; i++) {
        recogniser.emitError('error_client');
        await settle();
      }

      // Three visible attempts, still alive: a long session is not killed by
      // occasional trouble.
      expect(seen.whereType<SttReconnecting>().length, 3);
      expect(seen.whereType<SttFailed>(), isEmpty);
    });

    test(
      'trouble that never stops ends the session rather than looping',
      () async {
        await adapter.start(const SttRequest(language: LanguageTag.english));
        final List<SttEvent> seen = <SttEvent>[];
        adapter.events.listen(seen.add);

        for (int i = 0; i < 5; i++) {
          recogniser.emitError('error_client');
          await settle();
        }

        expect(seen.whereType<SttFailed>().length, 1);
      },
    );

    test('a success resets the failure budget', () async {
      await adapter.start(const SttRequest(language: LanguageTag.english));
      final List<SttEvent> seen = <SttEvent>[];
      adapter.events.listen(seen.add);

      for (int i = 0; i < 3; i++) {
        recogniser.emitError('error_client');
        await settle();
      }
      recogniser.emitFinal('it recovered');
      for (int i = 0; i < 3; i++) {
        recogniser.emitError('error_client');
        await settle();
      }

      // Without the reset an hour-long session would die of accumulated
      // hiccups it had already recovered from.
      expect(seen.whereType<SttFailed>(), isEmpty);
    });
  });

  group('stopping', () {
    test('stopping ends the session exactly once, as asked', () async {
      await adapter.start(const SttRequest(language: LanguageTag.english));
      final List<SttEvent> seen = <SttEvent>[];
      adapter.events.listen(seen.add);

      await adapter.stop();
      await settle();

      expect(
        seen.whereType<SttEnded>().single.reason,
        SttEndReason.stoppedByUser,
      );
    });

    test('a stopped session does not restart itself', () async {
      await adapter.start(const SttRequest(language: LanguageTag.english));
      await adapter.stop();
      final int after = recogniser.listens;

      // The engine reports the segment's end after the stop; that must not
      // revive a session the user has closed.
      recogniser.emitStatus('done');
      await settle();

      expect(recogniser.listens, after);
    });

    test('stopping twice is safe and does not end twice', () async {
      await adapter.start(const SttRequest(language: LanguageTag.english));
      final List<SttEvent> seen = <SttEvent>[];
      adapter.events.listen(seen.add);

      await adapter.stop();
      await adapter.stop();
      await settle();

      expect(seen.whereType<SttEnded>().length, 1);
    });

    test('events after dispose change nothing and do not throw', () async {
      await adapter.start(const SttRequest(language: LanguageTag.english));
      await adapter.dispose();

      expect(() {
        recogniser.emitFinal('too late');
        recogniser.emitStatus('done');
        recogniser.emitError('error_client');
      }, returnsNormally);
    });

    test('starting after dispose fails instead of throwing', () async {
      await adapter.dispose();

      final Result<Unit, SttFailure> result = await adapter.start(
        const SttRequest(language: LanguageTag.english),
      );

      expect(result.errorOrNull!.code, FailureCode.cancelled);
    });
  });
}
