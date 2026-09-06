import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/application/speech/speech_setup_controller.dart';
import 'package:humsukhan/core/failure/failure.dart';
import 'package:humsukhan/domain/speech/capability.dart';
import 'package:humsukhan/domain/speech/language_tag.dart';
import 'package:humsukhan/domain/speech/speech_install_port.dart';

/// A capability port the test moves from "missing" to "installed" by hand,
/// which is exactly what a real install does underneath.
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

/// An installer the test drives event by event.
class _FakeInstaller implements SpeechInstallPort {
  bool guided = true;
  // Broadcast so a test that never subscribes can still be torn down: closing
  // an unlistened single-subscription controller simply never completes.
  // ignore: close_sinks — closed by the tearDown below.
  final StreamController<InstallProgress> controller =
      StreamController<InstallProgress>.broadcast();
  int installs = 0;

  @override
  Future<bool> canInstall(SpeechFacility facility) async => guided;

  @override
  Stream<InstallProgress> install(
    SpeechFacility facility,
    LanguageTag language,
  ) {
    installs++;
    return controller.stream;
  }
}

void main() {
  late _FakeCapability capability;
  late _FakeInstaller installer;
  late SpeechSetupController controller;

  setUp(() {
    capability = _FakeCapability();
    installer = _FakeInstaller();
    controller = SpeechSetupController(
      capability: capability,
      installer: installer,
    );
  });

  tearDown(() async {
    await controller.dispose();
    if (!installer.controller.isClosed) await installer.controller.close();
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  group('a language that is already there is never mentioned', () {
    test('an available capability runs the action straight away', () async {
      capability.sttAnswer = const CapabilityAvailable();
      bool ran = false;

      final bool proceeded = await controller.ensure(
        facility: SpeechFacility.recognition,
        language: LanguageTag.urdu,
        action: () async => ran = true,
      );

      expect(proceeded, isTrue);
      expect(ran, isTrue);
      // No sheet, no dialog, no interruption.
      expect(controller.state.isActive, isFalse);
    });

    test('an unasked question does not block the user', () async {
      capability.sttAnswer = const CapabilityUnknown();
      bool ran = false;

      final bool proceeded = await controller.ensure(
        facility: SpeechFacility.recognition,
        language: LanguageTag.english,
        action: () async => ran = true,
      );

      // Refusing here would disable working hardware over a probe that merely
      // failed to answer — the worse of the two mistakes.
      expect(proceeded, isTrue);
      expect(ran, isTrue);
    });
  });

  group('a missing language opens the flow instead of the feature', () {
    test('the action is held rather than run', () async {
      bool ran = false;

      final bool proceeded = await controller.ensure(
        facility: SpeechFacility.recognition,
        language: LanguageTag.urdu,
        action: () async => ran = true,
      );

      expect(proceeded, isFalse);
      expect(ran, isFalse);
      expect(controller.state.isActive, isTrue);
      expect(controller.state.canInstall, isTrue);
      expect(controller.state.facility, SpeechFacility.recognition);
      expect(controller.state.language, LanguageTag.urdu);
    });

    test(
      'a device with no installer says so instead of offering a button',
      () async {
        installer.guided = false;

        await controller.ensure(
          facility: SpeechFacility.synthesis,
          language: LanguageTag.urdu,
        );

        expect(controller.state.canInstall, isFalse);
        final InstallFailed failure = controller.state.failure!;
        expect(failure.reason, FailureCode.ttsVoiceMissing);
        // Offering a retry that cannot succeed is its own defect.
        expect(failure.canRetry, isFalse);
      },
    );
  });

  group('accepting the download', () {
    test('progress is passed through as the platform reports it', () async {
      await controller.ensure(
        facility: SpeechFacility.recognition,
        language: LanguageTag.urdu,
      );
      await controller.accept();

      installer.controller.add(const InstallDownloading(0.4));
      await settle();

      expect(controller.state.progress, const InstallDownloading(0.4));
    });

    test('completion runs the held action and closes the flow', () async {
      bool ran = false;
      await controller.ensure(
        facility: SpeechFacility.recognition,
        language: LanguageTag.urdu,
        action: () async => ran = true,
      );
      await controller.accept();

      installer.controller.add(const InstallCompleted());
      await settle();

      // The whole point: the user pressed one button and ended up where they
      // were going, without finding the feature again themselves.
      expect(ran, isTrue);
      expect(controller.state.isActive, isFalse);
    });

    test('a failure is shown and the action is not run', () async {
      bool ran = false;
      await controller.ensure(
        facility: SpeechFacility.recognition,
        language: LanguageTag.urdu,
        action: () async => ran = true,
      );
      await controller.accept();

      installer.controller.add(
        const InstallFailed(FailureCode.modelDownloadFailed),
      );
      await settle();

      expect(ran, isFalse);
      expect(controller.state.failure!.reason, FailureCode.modelDownloadFailed);
      expect(controller.state.failure!.canRetry, isTrue);
    });

    test('a retry after a failure starts a fresh install', () async {
      await controller.ensure(
        facility: SpeechFacility.recognition,
        language: LanguageTag.urdu,
      );
      await controller.accept();
      installer.controller.add(const InstallFailed(FailureCode.timeout));
      await settle();

      await controller.accept();

      expect(installer.installs, 2);
      expect(controller.state.progress, const InstallStarting());
    });

    test('a stream that ends without a verdict fails loudly', () async {
      await controller.ensure(
        facility: SpeechFacility.recognition,
        language: LanguageTag.urdu,
      );
      await controller.accept();

      installer.controller.add(const InstallDownloading(0.5));
      await settle();
      await installer.controller.close();
      await settle();

      // A spinner with no end is the state this app refuses to have.
      expect(controller.state.failure, isNotNull);
    });
  });

  group('returning from a system installer', () {
    test(
      'a completed install is detected on resume and resumes the action',
      () async {
        bool ran = false;
        await controller.ensure(
          facility: SpeechFacility.synthesis,
          language: LanguageTag.urdu,
          action: () async => ran = true,
        );
        await controller.accept();

        installer.controller.add(const InstallHandedOff());
        await settle();
        expect(controller.state.awaitsResume, isTrue);

        // The user installs the voice and comes back.
        capability.ttsAnswer = const CapabilityAvailable();
        await controller.onResumed();

        expect(ran, isTrue);
        expect(controller.state.isActive, isFalse);
      },
    );

    test(
      'coming back without installing offers it again, without scolding',
      () async {
        await controller.ensure(
          facility: SpeechFacility.synthesis,
          language: LanguageTag.urdu,
        );
        await controller.accept();
        installer.controller.add(const InstallHandedOff());
        await settle();

        await controller.onResumed();

        final InstallFailed failure = controller.state.failure!;
        expect(failure.reason, FailureCode.ttsVoiceMissing);
        expect(failure.canRetry, isTrue);
      },
    );

    test('resume always re-asks the engine, flow or no flow', () async {
      await controller.onResumed();

      // A device that gained a voice in the background must be able to
      // discover it even when nothing was mid-install (B9).
      expect(capability.invalidations, 1);
    });
  });

  test('dismissing abandons the held action', () async {
    bool ran = false;
    await controller.ensure(
      facility: SpeechFacility.recognition,
      language: LanguageTag.urdu,
      action: () async => ran = true,
    );

    controller.dismiss();
    await settle();

    expect(controller.state.isActive, isFalse);
    expect(ran, isFalse);
  });

  test('nothing is touched after dispose', () async {
    await controller.ensure(
      facility: SpeechFacility.recognition,
      language: LanguageTag.urdu,
    );
    await controller.dispose();

    await expectLater(controller.accept(), completes);
    await expectLater(controller.onResumed(), completes);
  });
}
