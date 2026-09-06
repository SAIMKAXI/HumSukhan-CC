import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/application/conversation/conversation_session.dart';
import 'package:humsukhan/application/conversation/conversation_session_state.dart';
import 'package:humsukhan/application/environment/monitoring_controller.dart';
import 'package:humsukhan/application/providers.dart';
import 'package:humsukhan/domain/conversation/caption.dart';
import 'package:humsukhan/domain/conversation/turn_policy.dart';
import 'package:humsukhan/domain/environment/sound_event.dart';
import 'package:humsukhan/domain/settings/app_settings.dart';
import 'package:humsukhan/domain/speech/language_tag.dart';
import 'package:humsukhan/features/environment/environment_screen.dart';

import '../fakes/fake_app_ports.dart';
import '../support/harness.dart';

/// A live session must survive a settings change.
///
/// These tests exist because the widget suite found the opposite: the session
/// and monitoring notifiers watched the whole settings object, so changing any
/// preference disposed the running object and built a fresh one. Monitoring's
/// own "enabled" flag did it too, which made the toggle appear to do nothing.
void main() {
  late ProviderContainer container;

  ProviderContainer buildContainer(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(Scaffold)));

  /// The app keeps both notifiers watched for the life of the session: the
  /// Everyday and Alerts screens sit in an IndexedStack that is never torn
  /// down. This mirrors that, because a provider nobody watches is paused and
  /// its listeners do not run.
  const Widget watcher = Scaffold(body: _Watcher());

  testWidgets('changing the theme does not restart the conversation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(harness(child: watcher));
    await settle(tester);
    container = buildContainer(tester);

    final ConversationSession before = container
        .read(conversationProvider.notifier)
        .session;
    before.begin();
    final Caption? caption = before.sendTyped('do not lose me');
    expect(caption, isNotNull);

    await container
        .read(settingsControllerProvider.notifier)
        .controller
        .setDarkMode(true);
    await tester.pump();

    final ConversationSession after = container
        .read(conversationProvider.notifier)
        .session;
    expect(
      identical(before, after),
      isTrue,
      reason: 'a theme change must not tear down a live conversation',
    );
    expect(after.state.captions, hasLength(1));
    expect(after.state.stage, ConversationStage.active);
  });

  testWidgets('changing the pause threshold reaches the live session', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(harness(child: watcher));
    await settle(tester);
    container = buildContainer(tester);

    final ConversationSession session = container
        .read(conversationProvider.notifier)
        .session;
    session.begin();

    await container
        .read(settingsControllerProvider.notifier)
        .controller
        .setPauseThreshold(PauseThreshold.patient);
    await tester.pumpAndSettle();

    expect(session.state.threshold, PauseThreshold.patient);
    expect(
      identical(session, container.read(conversationProvider.notifier).session),
      isTrue,
    );
  });

  testWidgets('changing the caption language reaches the live session', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(harness(child: watcher));
    await settle(tester);
    container = buildContainer(tester);

    final ConversationSession session = container
        .read(conversationProvider.notifier)
        .session;

    await container
        .read(settingsControllerProvider.notifier)
        .controller
        .setCaptionLanguage(LanguageTag.urdu);
    await tester.pumpAndSettle();

    expect(session.captionLanguage, LanguageTag.urdu);
  });

  testWidgets('persisting the monitoring flag does not restart monitoring', (
    WidgetTester tester,
  ) async {
    final FakeSoundDetector detector = FakeSoundDetector();
    await tester.pumpWidget(harness(child: watcher, detector: detector));
    await settle(tester);
    container = buildContainer(tester);

    final MonitoringController before = container
        .read(monitoringProvider.notifier)
        .controller;
    await before.start();
    expect(before.state.phase, MonitoringPhase.active);

    await container
        .read(settingsControllerProvider.notifier)
        .controller
        .setMonitoringEnabled(true);
    await tester.pump();

    final MonitoringController after = container
        .read(monitoringProvider.notifier)
        .controller;
    expect(
      identical(before, after),
      isTrue,
      reason: 'writing the enabled flag must not replace a running monitor',
    );
    expect(container.read(monitoringProvider).phase, MonitoringPhase.active);
  });

  testWidgets('changing alert channels reaches the running monitor', (
    WidgetTester tester,
  ) async {
    final RecordingAlertPresenter presenter = RecordingAlertPresenter();
    final FakeSoundDetector detector = FakeSoundDetector();
    await tester.pumpWidget(
      harness(child: watcher, detector: detector, presenter: presenter),
    );
    await settle(tester);
    container = buildContainer(tester);

    final MonitoringController controller = container
        .read(monitoringProvider.notifier)
        .controller;
    await controller.start();

    await container
        .read(settingsControllerProvider.notifier)
        .controller
        .setAlertChannels(const AlertChannels(torch: true));
    await tester.pumpAndSettle();

    detector.observe(SoundKind.alarm, 0.95, DateTime.now());
    await tester.pumpAndSettle();

    expect(presenter.channels.single.torch, isTrue);
    expect(
      identical(
        controller,
        container.read(monitoringProvider.notifier).controller,
      ),
      isTrue,
    );
  });

  testWidgets('the environment toggle actually starts monitoring', (
    WidgetTester tester,
  ) async {
    final FakeSoundDetector detector = FakeSoundDetector();
    await tester.pumpWidget(
      harness(child: const EnvironmentScreen(), detector: detector),
    );
    await settle(tester);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(
      detector.startCount,
      1,
      reason: 'the toggle must reach the detector, not a replaced controller',
    );
  });
}

/// Watches the long-lived notifiers, as the app's IndexedStack does.
class _Watcher extends ConsumerWidget {
  const _Watcher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref
      ..watch(conversationProvider)
      ..watch(monitoringProvider)
      ..watch(settingsProvider);
    return const SizedBox.shrink();
  }
}
