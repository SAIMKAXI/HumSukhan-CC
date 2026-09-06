import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/core/failure/failure.dart';
import 'package:humsukhan/core/l10n/app_strings.dart';
import 'package:humsukhan/domain/environment/detector_port.dart';
import 'package:humsukhan/domain/environment/model_state.dart';
import 'package:humsukhan/domain/environment/sound_event.dart';
import 'package:humsukhan/features/environment/environment_screen.dart';
import 'package:humsukhan/features/shared/badges.dart';

import '../../fakes/fake_app_ports.dart';
import '../../support/harness.dart';

void main() {
  group('the monitoring banner names its state', () {
    testWidgets('off by default, with the on-device promise visible', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(harness(child: const EnvironmentScreen()));
      await settle(tester);

      expect(find.text(english(StringKey.envStateOff)), findsOneWidget);
      expect(find.text(english(StringKey.envOnDeviceNotice)), findsWidgets);
    });

    testWidgets('turning it on reaches the active state', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(harness(child: const EnvironmentScreen()));
      await settle(tester);

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      expect(find.text(english(StringKey.envStateActive)), findsOneWidget);
    });

    testWidgets('a model that will not load blocks it with a reason', (
      WidgetTester tester,
    ) async {
      final FakeModelRepository models = FakeModelRepository()
        ..nextState = const ModelFailed(ModelFailure(FailureCode.modelCorrupt));

      await tester.pumpWidget(
        harness(child: const EnvironmentScreen(), models: models),
      );
      await settle(tester);

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      expect(find.text(english(StringKey.envStateFailed)), findsOneWidget);
      expect(
        find.textContaining(english.failureMessage(FailureCode.modelCorrupt)),
        findsOneWidget,
      );
      expect(
        find.textContaining(english.failureRemedy(FailureCode.modelCorrupt)!),
        findsOneWidget,
        reason: 'a blocked safety feature must name the way out',
      );
    });

    testWidgets('a refused microphone is stated, not silent', (
      WidgetTester tester,
    ) async {
      final FakeSoundDetector detector = FakeSoundDetector()
        ..failOnStart = const DetectorFailure(
          FailureCode.microphonePermissionDenied,
        );

      await tester.pumpWidget(
        harness(child: const EnvironmentScreen(), detector: detector),
      );
      await settle(tester);

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          english.failureMessage(FailureCode.microphonePermissionDenied),
        ),
        findsOneWidget,
      );
    });
  });

  group('what it listens for', () {
    testWidgets('every promised sound is named on screen', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(harness(child: const EnvironmentScreen()));
      await settle(tester);

      for (final SoundKind kind in SoundKind.values) {
        expect(
          find.text(english(soundKindLabel(kind))),
          findsOneWidget,
          reason: '${kind.name} is promised but not listed',
        );
      }
    });

    test('every sound and severity is named in both languages', () {
      for (final SoundKind kind in SoundKind.values) {
        expect(english(soundKindLabel(kind)), isNotEmpty);
        expect(urdu(soundKindLabel(kind)), isNotEmpty);
      }
      for (final AlertSeverity severity in AlertSeverity.values) {
        expect(english(SeverityBadge.labelKey(severity)), isNotEmpty);
        expect(urdu(SeverityBadge.labelKey(severity)), isNotEmpty);
      }
    });
  });

  group('alert history', () {
    testWidgets('shows an empty state before anything is heard', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(harness(child: const EnvironmentScreen()));
      await settle(tester);

      expect(find.text(english(StringKey.envNoAlerts)), findsWidgets);
    });

    testWidgets('dismissing an alert marks it seen and keeps the record', (
      WidgetTester tester,
    ) async {
      final FakeSoundDetector detector = FakeSoundDetector();

      await tester.pumpWidget(
        harness(child: const EnvironmentScreen(), detector: detector),
      );
      await settle(tester);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      detector.observe(SoundKind.alarm, 0.95, DateTime.now());
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.close), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.close), findsNothing);
      expect(
        find.byIcon(Icons.check),
        findsOneWidget,
        reason: 'dismissing marks the alert seen, it does not erase it',
      );
      expect(
        find.text(english(soundKindLabel(SoundKind.alarm))),
        findsNWidgets(2),
      );
    });

    testWidgets('a detected sound appears with severity and confidence', (
      WidgetTester tester,
    ) async {
      final FakeSoundDetector detector = FakeSoundDetector();

      await tester.pumpWidget(
        harness(child: const EnvironmentScreen(), detector: detector),
      );
      await settle(tester);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      detector.observe(SoundKind.alarm, 0.95, DateTime.now());
      await tester.pumpAndSettle();

      expect(
        find.text(english(soundKindLabel(SoundKind.alarm))),
        findsNWidgets(2), // once in the supported list, once in the history
      );
      expect(find.text(english(StringKey.envSeverityCritical)), findsOneWidget);
      expect(find.textContaining('95%'), findsOneWidget);
    });
  });
}
