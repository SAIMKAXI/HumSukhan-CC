import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/core/failure/failure.dart';
import 'package:humsukhan/domain/speech/capability.dart';
import 'package:humsukhan/domain/speech/language_tag.dart';
import 'package:humsukhan/domain/speech/speech_install_port.dart';
import 'package:humsukhan/infrastructure/speech/platform_speech_installer.dart';

/// A capability port the test moves from missing to installed by hand, which
/// is what a real download does underneath.
class _FakeCapability implements SpeechCapabilityPort {
  Capability sttAnswer = const CapabilityUnavailable(
    FailureCode.sttLanguageUnsupported,
  );
  Capability ttsAnswer = const CapabilityUnavailable(
    FailureCode.ttsVoiceMissing,
  );
  int invalidations = 0;

  @override
  Future<Capability> stt(LanguageTag language) async => sttAnswer;

  @override
  Future<Capability> tts(LanguageTag language) async => ttsAnswer;

  @override
  Future<void> invalidate() async => invalidations++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeCapability capability;
  late List<MethodCall> calls;
  late StreamController<Object?> platformEvents;
  late PlatformSpeechInstaller installer;

  /// What the method channel should do for each method name.
  late Map<String, Object? Function()> handlers;

  setUp(() {
    capability = _FakeCapability();
    calls = <MethodCall>[];
    platformEvents = StreamController<Object?>.broadcast();
    handlers = <String, Object? Function()>{};

    const MethodChannel methods = MethodChannel(
      PlatformSpeechInstaller.methodChannelName,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methods, (MethodCall call) async {
          calls.add(call);
          final Object? Function()? handler = handlers[call.method];
          if (handler == null) return null;
          return handler();
        });

    installer = PlatformSpeechInstaller(
      capability: capability,
      methods: methods,
      events: _FakeEventChannel(platformEvents.stream),
      pollInterval: const Duration(milliseconds: 10),
      downloadTimeout: const Duration(milliseconds: 400),
      settleTimeout: const Duration(milliseconds: 100),
    );
  });

  tearDown(() async {
    await platformEvents.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel(PlatformSpeechInstaller.methodChannelName),
          null,
        );
  });

  group('canInstall', () {
    test('reports what the platform says', () async {
      handlers['canInstall'] = () => true;

      expect(await installer.canInstall(SpeechFacility.recognition), isTrue);
    });

    test('a platform with no channel simply has no guided install', () async {
      handlers['canInstall'] = () => throw MissingPluginException();

      // iOS, or a widget test. Reporting false is correct; throwing would
      // break every caller.
      expect(await installer.canInstall(SpeechFacility.synthesis), isFalse);
    });
  });

  group('recognition', () {
    test('a language already present is never downloaded', () async {
      capability.sttAnswer = const CapabilityAvailable();

      final List<InstallProgress> seen = await installer
          .install(SpeechFacility.recognition, LanguageTag.urdu)
          .toList();

      expect(seen.last, const InstallCompleted());
      // The worst outcome this check prevents: sending someone to install
      // what they already have.
      expect(
        calls.map((MethodCall c) => c.method),
        isNot(contains('installStt')),
      );
    });

    test('platform progress is passed through as reported', () async {
      handlers['installStt'] = () {
        scheduleMicrotask(() {
          platformEvents.add(<Object?, Object?>{
            'state': 'downloading',
            'progress': 0.25,
          });
          platformEvents.add(<Object?, Object?>{'state': 'completed'});
        });
        return 'started';
      };
      // The engine has it by the time completion is verified.
      Timer(const Duration(milliseconds: 5), () {
        capability.sttAnswer = const CapabilityAvailable();
      });

      final List<InstallProgress> seen = await installer
          .install(SpeechFacility.recognition, LanguageTag.urdu)
          .toList();

      expect(seen, contains(const InstallDownloading(0.25)));
      expect(seen, contains(const InstallVerifying()));
      expect(seen.last, const InstallCompleted());
    });

    test('a queued download shows an honest indeterminate bar', () async {
      handlers['installStt'] = () {
        scheduleMicrotask(
          () => platformEvents.add(<Object?, Object?>{'state': 'scheduled'}),
        );
        return 'started';
      };
      Timer(const Duration(milliseconds: 30), () {
        capability.sttAnswer = const CapabilityAvailable();
      });

      final List<InstallProgress> seen = await installer
          .install(SpeechFacility.recognition, LanguageTag.urdu)
          .toList();

      // A percentage here would be invented; null renders as indeterminate.
      expect(seen, contains(const InstallDownloading(null)));
      expect(seen.last, const InstallCompleted());
    });

    test(
      'Android 13 reports nothing, so the engine is polled instead',
      () async {
        handlers['installStt'] = () => 'started';
        Timer(const Duration(milliseconds: 30), () {
          capability.sttAnswer = const CapabilityAvailable();
        });

        final List<InstallProgress> seen = await installer
            .install(SpeechFacility.recognition, LanguageTag.urdu)
            .toList();

        // Without the poll this would time out on a download that worked.
        expect(seen.last, const InstallCompleted());
      },
    );

    test('a platform failure is reported and can be retried', () async {
      handlers['installStt'] = () {
        scheduleMicrotask(
          () => platformEvents.add(<Object?, Object?>{'state': 'failed'}),
        );
        return 'started';
      };

      final List<InstallProgress> seen = await installer
          .install(SpeechFacility.recognition, LanguageTag.urdu)
          .toList();

      final InstallFailed failure = seen.last as InstallFailed;
      expect(failure.reason, FailureCode.modelDownloadFailed);
      expect(failure.canRetry, isTrue);
    });

    test('an unsupported device does not offer a pointless retry', () async {
      handlers['installStt'] = () =>
          throw PlatformException(code: 'unsupported');

      final List<InstallProgress> seen = await installer
          .install(SpeechFacility.recognition, LanguageTag.urdu)
          .toList();

      final InstallFailed failure = seen.last as InstallFailed;
      expect(failure.canRetry, isFalse);
    });

    test(
      'a download that never finishes times out rather than hanging',
      () async {
        handlers['installStt'] = () => 'started';

        final List<InstallProgress> seen = await installer
            .install(SpeechFacility.recognition, LanguageTag.urdu)
            .toList();

        // A spinner with no end is the state this app refuses to have.
        expect((seen.last as InstallFailed).reason, FailureCode.timeout);
      },
    );

    test(
      'a platform that claims success the engine denies is a failure',
      () async {
        handlers['installStt'] = () {
          scheduleMicrotask(
            () => platformEvents.add(<Object?, Object?>{'state': 'completed'}),
          );
          return 'started';
        };
        // The engine never gains the language.

        final List<InstallProgress> seen = await installer
            .install(SpeechFacility.recognition, LanguageTag.urdu)
            .toList();

        // Believing the platform here would drop the user back at a feature
        // that still does not work.
        expect(seen.last, isA<InstallFailed>());
      },
    );

    test('every run ends in a terminal state', () async {
      handlers['installStt'] = () => 'started';

      final List<InstallProgress> seen = await installer
          .install(SpeechFacility.recognition, LanguageTag.urdu)
          .toList();

      expect(seen.last.isTerminal, isTrue);
    });
  });

  group('synthesis', () {
    test('the installer is launched and the flow waits for the user', () async {
      handlers['installTts'] = () => 'handedOff';

      final List<InstallProgress> seen = await installer
          .install(SpeechFacility.synthesis, LanguageTag.urdu)
          .toList();

      expect(seen.last, const InstallHandedOff());
      expect(calls.map((MethodCall c) => c.method), contains('installTts'));
    });

    test('a voice already present skips the installer entirely', () async {
      capability.ttsAnswer = const CapabilityAvailable();

      final List<InstallProgress> seen = await installer
          .install(SpeechFacility.synthesis, LanguageTag.urdu)
          .toList();

      expect(seen.last, const InstallCompleted());
      expect(
        calls.map((MethodCall c) => c.method),
        isNot(contains('installTts')),
      );
    });

    test('a device with no installer does not offer a retry', () async {
      handlers['installTts'] = () =>
          throw PlatformException(code: 'unsupported');

      final List<InstallProgress> seen = await installer
          .install(SpeechFacility.synthesis, LanguageTag.urdu)
          .toList();

      expect((seen.last as InstallFailed).canRetry, isFalse);
    });
  });

  test('the cached answer is dropped before every check', () async {
    capability.sttAnswer = const CapabilityAvailable();

    await installer
        .install(SpeechFacility.recognition, LanguageTag.urdu)
        .toList();

    // Without this the "no" cached before the install would answer forever
    // and the flow could never succeed.
    expect(capability.invalidations, greaterThan(0));
  });
}

/// An [EventChannel] whose broadcast stream the test supplies.
class _FakeEventChannel implements EventChannel {
  _FakeEventChannel(this._stream);

  final Stream<Object?> _stream;

  @override
  Stream<Object?> receiveBroadcastStream([Object? arguments]) => _stream;

  @override
  String get name => 'fake';

  @override
  MethodCodec get codec => const StandardMethodCodec();

  @override
  BinaryMessenger get binaryMessenger =>
      throw UnimplementedError('not used by the installer');
}
