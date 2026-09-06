import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/application/providers.dart';
import 'package:humsukhan/core/failure/failure.dart';
import 'package:humsukhan/core/l10n/app_language.dart';
import 'package:humsukhan/core/l10n/app_strings.dart';
import 'package:humsukhan/domain/speech/capability.dart';
import 'package:humsukhan/domain/speech/language_tag.dart';
import 'package:humsukhan/domain/speech/speech_install_port.dart';
import 'package:humsukhan/features/speech/speech_setup_sheet.dart';

import '../../fakes/fake_speech_ports.dart';
import '../../support/harness.dart';

void main() {
  final AppStrings strings = AppStrings.of(AppLanguage.english);

  /// A screen with one button that needs an Urdu voice, under the sheet.
  Widget subject({
    required FakeCapabilityPort capability,
    required FakeSpeechInstallPort installer,
    required void Function() onSpoke,
  }) => harness(
    capability: capability,
    speechInstaller: installer,
    child: SpeechSetupSheet(
      child: Consumer(
        builder: (BuildContext context, WidgetRef ref, Widget? _) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => ref
                  .read(speechSetupProvider.notifier)
                  .controller
                  .ensure(
                    facility: SpeechFacility.synthesis,
                    language: LanguageTag.urdu,
                    action: () async => onSpoke(),
                  ),
              child: const Text('Speak'),
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('a phone that already has the voice just speaks', (
    WidgetTester tester,
  ) async {
    bool spoke = false;
    await tester.pumpWidget(
      subject(
        capability: FakeCapabilityPort(),
        installer: FakeSpeechInstallPort(),
        onSpoke: () => spoke = true,
      ),
    );

    await tester.tap(find.text('Speak'));
    await tester.pumpAndSettle();

    expect(spoke, isTrue);
    // Nothing is shown at all. The user is not told about machinery that
    // already works.
    expect(find.text(strings(StringKey.setupTtsTitle)), findsNothing);
  });

  testWidgets('a missing voice explains itself in plain language', (
    WidgetTester tester,
  ) async {
    bool spoke = false;
    await tester.pumpWidget(
      subject(
        capability: FakeCapabilityPort(
          ttsAnswers: <LanguageTag, Capability>{
            LanguageTag.urdu: const CapabilityUnavailable(
              FailureCode.ttsVoiceMissing,
            ),
          },
        ),
        installer: FakeSpeechInstallPort(),
        onSpoke: () => spoke = true,
      ),
    );

    await tester.tap(find.text('Speak'));
    await tester.pumpAndSettle();

    expect(find.text(strings(StringKey.setupTtsTitle)), findsOneWidget);
    expect(find.text(strings(StringKey.setupTtsBody)), findsOneWidget);
    // One button to proceed, one to leave. No settings path, no jargon.
    expect(find.text(strings(StringKey.setupDownload)), findsOneWidget);
    expect(find.text(strings(StringKey.setupNotNow)), findsOneWidget);
    expect(spoke, isFalse);
  });

  testWidgets('accepting installs and then does what the user asked', (
    WidgetTester tester,
  ) async {
    bool spoke = false;
    final FakeCapabilityPort capability = FakeCapabilityPort(
      ttsAnswers: <LanguageTag, Capability>{
        LanguageTag.urdu: const CapabilityUnavailable(
          FailureCode.ttsVoiceMissing,
        ),
      },
    );
    await tester.pumpWidget(
      subject(
        capability: capability,
        installer: FakeSpeechInstallPort()
          ..progress = const <InstallProgress>[
            InstallStarting(),
            InstallDownloading(0.5),
            InstallCompleted(),
          ],
        onSpoke: () => spoke = true,
      ),
    );

    await tester.tap(find.text('Speak'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings(StringKey.setupDownload)));
    await tester.pumpAndSettle();

    // The point of the whole flow: they pressed one button and ended up where
    // they were going.
    expect(spoke, isTrue);
    expect(find.text(strings(StringKey.setupTtsTitle)), findsNothing);
  });

  testWidgets('a failed download offers a retry, not a dead end', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      subject(
        capability: FakeCapabilityPort(
          ttsAnswers: <LanguageTag, Capability>{
            LanguageTag.urdu: const CapabilityUnavailable(
              FailureCode.ttsVoiceMissing,
            ),
          },
        ),
        installer: FakeSpeechInstallPort()
          ..progress = const <InstallProgress>[
            InstallStarting(),
            InstallFailed(FailureCode.modelDownloadFailed),
          ],
        onSpoke: () {},
      ),
    );

    await tester.tap(find.text('Speak'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings(StringKey.setupDownload)));
    await tester.pumpAndSettle();

    expect(find.textContaining(strings(StringKey.setupFailed)), findsOneWidget);
    expect(find.text(strings(StringKey.retry)), findsOneWidget);
  });

  testWidgets(
    'a phone with no installer says so instead of offering a button',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        subject(
          capability: FakeCapabilityPort(
            ttsAnswers: <LanguageTag, Capability>{
              LanguageTag.urdu: const CapabilityUnavailable(
                FailureCode.ttsVoiceMissing,
              ),
            },
          ),
          installer: FakeSpeechInstallPort(guided: false),
          onSpoke: () {},
        ),
      );

      await tester.tap(find.text('Speak'));
      await tester.pumpAndSettle();

      expect(find.text(strings(StringKey.setupUnsupported)), findsOneWidget);
      // An inert Download button would be worse than the honest sentence.
      expect(find.text(strings(StringKey.setupDownload)), findsNothing);
      expect(find.text(strings(StringKey.retry)), findsNothing);
    },
  );

  testWidgets('dismissing returns the user to what they were doing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      subject(
        capability: FakeCapabilityPort(
          ttsAnswers: <LanguageTag, Capability>{
            LanguageTag.urdu: const CapabilityUnavailable(
              FailureCode.ttsVoiceMissing,
            ),
          },
        ),
        installer: FakeSpeechInstallPort(),
        onSpoke: () {},
      ),
    );

    await tester.tap(find.text('Speak'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings(StringKey.setupNotNow)));
    await tester.pumpAndSettle();

    expect(find.text(strings(StringKey.setupTtsTitle)), findsNothing);
    expect(find.text('Speak'), findsOneWidget);
  });
}
