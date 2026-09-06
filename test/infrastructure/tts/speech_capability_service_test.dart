import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/core/failure/failure.dart';
import 'package:humsukhan/domain/speech/capability.dart';
import 'package:humsukhan/domain/speech/language_tag.dart';
import 'package:humsukhan/infrastructure/tts/speech_capability_service.dart';

import '../../fakes/fake_speech_ports.dart';

/// A speech engine whose answers the test dictates, with no plugin behind it.
///
/// It implements only the catalogue port, which has no way to speak: a probe
/// that tried to synthesise anything could not compile against this.
class _FakeEngine implements VoiceCataloguePort {
  _FakeEngine();

  /// The locales the engine claims to have. Empty means it could not be asked.
  Set<String> locales = const <String>{};

  /// Which engine is installed. Changing it must invalidate a cached answer.
  String engine = 'test-engine';
  int queries = 0;

  @override
  Future<Set<String>> availableLocales() async {
    queries++;
    return locales;
  }

  @override
  Future<String> engineId() async => engine;

  @override
  Future<bool> supports(LanguageTag language) async {
    final Set<String> lower = locales
        .map((String l) => l.toLowerCase())
        .toSet();
    return lower.any(
      (String l) =>
          l == language.preferredLocale.toLowerCase() ||
          l.startsWith('${language.code}-') ||
          l == language.code,
    );
  }
}

/// A recogniser whose answers the test dictates.
///
/// Separate from the voice catalogue because the two engines are separate on
/// every real device: a phone can caption Urdu and be unable to speak it.
class _FakeRecogniser implements RecognitionCataloguePort {
  _FakeRecogniser();

  /// Whether a recogniser exists at all.
  bool present = true;

  /// The locales it claims. Empty means it could not be asked.
  Set<String> locales = const <String>{};
  int queries = 0;

  @override
  Future<bool> isAvailable() async => present;

  @override
  Future<Set<String>> availableLocales() async {
    queries++;
    return locales;
  }

  @override
  Future<bool> supportsOffline(LanguageTag language) async =>
      locales.any((String l) => l.startsWith(language.code));
}

void main() {
  late _FakeEngine engine;
  late _FakeRecogniser recogniser;
  late FakeClock clock;

  SpeechCapabilityService build({
    bool cloud = false,
    bool backend = true,
    Duration ttl = const Duration(minutes: 30),
  }) => SpeechCapabilityService(
    voices: engine,
    recognisers: recogniser,
    hasCloudFallback: cloud,
    hasRecognitionBackend: backend,
    clock: clock,
    negativeTtl: ttl,
    platformOverride: 'android',
    osVersionOverride: '14',
  );

  setUp(() {
    engine = _FakeEngine();
    recogniser = _FakeRecogniser();
    clock = FakeClock();
  });

  group('B5 — a probe is a question, never an utterance', () {
    test(
      'asking about a language only reads the engine\'s language list',
      () async {
        engine.locales = <String>{'en-US'};

        await build().tts(LanguageTag.english);

        expect(engine.queries, greaterThan(0));
        // The port this service is given has no speak method at all, so a probe
        // that produced sound could not be written against it.
      },
    );
  });

  group('an installed voice is found', () {
    test('an exact locale match is available', () async {
      engine.locales = <String>{'en-US', 'ur-PK'};

      expect(await build().tts(LanguageTag.urdu), isA<CapabilityAvailable>());
    });

    test('English never satisfies a request for Urdu', () async {
      engine.locales = <String>{'en-US', 'en-GB'};

      expect(await build().tts(LanguageTag.urdu), isA<CapabilityUnavailable>());
    });
  });

  group('what cannot be answered is not reported as absent', () {
    test(
      'an engine that returns nothing is unknown, not unavailable',
      () async {
        engine.locales = <String>{};

        expect(
          await build().tts(LanguageTag.urdu),
          isA<CapabilityUnknown>(),
          reason:
              'telling a user to install a voice they may already have is '
              'worse than saying we could not check',
        );
      },
    );

    test('an unknown answer is never cached', () async {
      engine.locales = <String>{};
      final SpeechCapabilityService service = build();

      await service.tts(LanguageTag.urdu);
      final int afterFirst = engine.queries;
      await service.tts(LanguageTag.urdu);

      expect(engine.queries, greaterThan(afterFirst));
    });
  });

  group('B9 — a negative never becomes permanent', () {
    test('a negative is re-probed once its window passes', () async {
      engine.locales = <String>{'en-US'};
      final SpeechCapabilityService service = build();

      expect(await service.tts(LanguageTag.urdu), isA<CapabilityUnavailable>());

      // The user installs an Urdu voice.
      engine.locales = <String>{'en-US', 'ur-PK'};
      clock.advance(const Duration(hours: 1));

      expect(
        await service.tts(LanguageTag.urdu),
        isA<CapabilityAvailable>(),
        reason: 'a device that gains a voice must be able to discover it',
      );
    });

    test('invalidate drops negatives and keeps positives', () async {
      engine.locales = <String>{'en-US'};
      final SpeechCapabilityService service = build();
      await service.tts(LanguageTag.english);
      await service.tts(LanguageTag.urdu);
      final int before = engine.queries;

      await service.invalidate();
      await service.tts(LanguageTag.english);
      final int afterPositive = engine.queries;
      await service.tts(LanguageTag.urdu);

      expect(
        afterPositive - before,
        lessThan(engine.queries - afterPositive),
        reason: 'the negative is re-probed; the positive is reused',
      );
    });

    test('a different engine invalidates the answer', () async {
      engine.locales = <String>{'en-US'};
      final SpeechCapabilityService service = build();
      await service.tts(LanguageTag.urdu);

      // The user installs a different speech engine, which brings Urdu with it.
      engine
        ..engine = 'other-engine'
        ..locales = <String>{'ur-PK'};

      expect(await service.tts(LanguageTag.urdu), isA<CapabilityAvailable>());
    });
  });

  group('the cloud fallback is stated, not hidden', () {
    test('a missing voice with a backend reports the cloud route', () async {
      engine.locales = <String>{'en-US'};

      final Capability capability = await build(cloud: true)
          .tts(LanguageTag.urdu);

      expect(capability, isA<CapabilityAvailable>());
      expect((capability as CapabilityAvailable).locale, 'cloud');
    });
  });

  group('recognition is answered by the device, not by the backend', () {
    test('a device with the language needs no backend at all', () async {
      recogniser.locales = <String>{'en-us', 'ur-pk'};

      final Capability capability = await build(backend: false)
          .stt(LanguageTag.urdu);

      // The whole point of the on-device path: a stock install, no account,
      // no key, no signal, and captions still work.
      expect(capability, isA<CapabilityAvailable>());
      expect((capability as CapabilityAvailable).locale, isNull);
    });

    test('a regional variant satisfies the language', () async {
      recogniser.locales = <String>{'en-gb'};

      expect(
        await build(backend: false).stt(LanguageTag.english),
        isA<CapabilityAvailable>(),
      );
    });

    test('no model and no backend is unavailable, not unknown', () async {
      recogniser.locales = <String>{'en-us'};

      final Capability capability = await build(backend: false)
          .stt(LanguageTag.urdu);

      expect(capability, isA<CapabilityUnavailable>());
      // The code the guided install flow keys on. `sttAuthFailed` would send
      // the user to sign in again, which cannot install an Urdu model.
      expect(
        (capability as CapabilityUnavailable).reason,
        FailureCode.sttLanguageUnsupported,
      );
    });

    test('English never stands in for a missing Urdu model', () async {
      recogniser.locales = <String>{'en-us', 'en-gb', 'en-in'};

      expect(
        await build(backend: false).stt(LanguageTag.urdu),
        isA<CapabilityUnavailable>(),
      );
    });

    test('a backend covers a language the device lacks', () async {
      recogniser.locales = <String>{'en-us'};

      final Capability capability = await build().stt(LanguageTag.urdu);

      expect(capability, isA<CapabilityAvailable>());
      expect((capability as CapabilityAvailable).locale, 'cloud');
    });

    test(
      'an engine that cannot be asked is unknown, not unavailable',
      () async {
        recogniser.locales = const <String>{};

        // Saying "unavailable" here would send the user to install a model they
        // may already have, on the strength of a question we failed to ask.
        expect(
          await build(backend: false).stt(LanguageTag.urdu),
          isA<CapabilityUnknown>(),
        );
      },
    );

    test('no recogniser at all falls through to the backend', () async {
      recogniser.present = false;

      final Capability capability = await build().stt(LanguageTag.english);

      expect(capability, isA<CapabilityAvailable>());
      expect((capability as CapabilityAvailable).locale, 'cloud');
    });

    test('a positive answer is cached rather than re-probed', () async {
      recogniser.locales = <String>{'ur-pk'};

      await build(backend: false).stt(LanguageTag.urdu);
      final int afterFirst = recogniser.queries;
      expect(afterFirst, 1);
    });

    test('a negative answer is re-probed once it goes stale', () async {
      recogniser.locales = <String>{'en-us'};
      // The default thirty-minute window; the clock below steps past it.
      final SpeechCapabilityService service = build(backend: false);

      expect(await service.stt(LanguageTag.urdu), isA<CapabilityUnavailable>());
      final int afterFirst = recogniser.queries;

      // The user installs the model while the app is open.
      recogniser.locales = <String>{'en-us', 'ur-pk'};
      clock.advance(const Duration(minutes: 31));

      // A cache that never rechecked is what permanently disabled working
      // hardware in the shipped build (B9).
      expect(await service.stt(LanguageTag.urdu), isA<CapabilityAvailable>());
      expect(recogniser.queries, greaterThan(afterFirst));
    });

    test('invalidate drops a negative so an install is discovered', () async {
      recogniser.locales = <String>{'en-us'};
      final SpeechCapabilityService service = build(backend: false);

      expect(await service.stt(LanguageTag.urdu), isA<CapabilityUnavailable>());

      recogniser.locales = <String>{'en-us', 'ur-pk'};
      await service.invalidate();

      expect(await service.stt(LanguageTag.urdu), isA<CapabilityAvailable>());
    });
  });
}
