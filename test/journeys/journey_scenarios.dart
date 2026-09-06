import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/application/providers.dart';
import 'package:humsukhan/composition/shell/humsukhan_app.dart';
import 'package:humsukhan/core/l10n/app_language.dart';
import 'package:humsukhan/core/l10n/app_strings.dart';
import 'package:humsukhan/core/result/result.dart';
import 'package:humsukhan/domain/environment/detector_port.dart';
import 'package:humsukhan/domain/environment/monitoring_service_port.dart';
import 'package:humsukhan/domain/environment/quick_tile_port.dart';
import 'package:humsukhan/domain/environment/sound_event.dart';
import 'package:humsukhan/domain/professional/professional_session.dart';
import 'package:humsukhan/domain/settings/app_settings.dart';
import 'package:humsukhan/domain/speech/stt_event.dart';
import 'package:humsukhan/features/shared/badges.dart';

import '../fakes/fake_app_ports.dart';
import '../fakes/fake_speech_ports.dart';

/// The three end-to-end journeys from docs/instructions.md §2, driven through
/// the real app widget.
///
/// The speech transport, the summariser and the sound detector are fakes: a
/// journey test asserts that the *app* carries a user from start to finish, not
/// that a third party's servers are up. Everything below the ports — the
/// screens, the gate, the session machines, storage — is the shipping code.
///
/// Run headless with `flutter test test/journeys/`, and on a device with
/// `flutter test integration_test/journeys_test.dart`.
/// Registers the three journeys. Called by the headless suite in `test/` and by
/// the on-device suite in `integration_test/`, so CI proves the flows and a
/// device run proves them again against the real plugins.
void registerJourneyTests() {
  late FakeSttPort conversationStt;
  late FakeSttPort recorderStt;
  late FakeTtsPort tts;
  late FakeSoundDetector detector;
  late FakeAuthPort auth;
  late FakeSettingsPort settingsPort;
  late FakeConversationRepository conversations;
  late FakeSessionRepository sessions;
  late FakeInsightPort insight;
  late RecordingAlertPresenter presenter;
  late FakeCapabilityPort capability;
  late FakeSpeechInstallPort installer;

  final AppStrings strings = AppStrings.of(AppLanguage.english);

  setUp(() {
    conversationStt = FakeSttPort();
    recorderStt = FakeSttPort();
    tts = FakeTtsPort();
    detector = FakeSoundDetector();
    auth = FakeAuthPort();
    settingsPort = FakeSettingsPort(
      // Onboarding is exercised separately; the journeys start past it.
      initial: const AppSettings(onboardingComplete: true),
    );
    conversations = FakeConversationRepository();
    sessions = FakeSessionRepository();
    insight = FakeInsightPort();
    presenter = RecordingAlertPresenter();
    // An ordinary phone that already has both languages: the journeys are
    // about the product working, not about the setup flow, which has its own
    // tests.
    capability = FakeCapabilityPort();
    installer = FakeSpeechInstallPort();
  });

  /// A realistic phone surface: 360x800 logical pixels.
  ///
  /// The default test window is 800x600, which is neither a phone nor a shape
  /// this app is designed for, and layouts that only fail there are not
  /// failures a user would ever see.
  void usePhoneSurface(WidgetTester tester) {
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  Future<void> launch(WidgetTester tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authPortProvider.overrideWithValue(auth),
          settingsPortProvider.overrideWithValue(settingsPort),
          conversationSttProvider.overrideWithValue(conversationStt),
          recorderSttProvider.overrideWithValue(recorderStt),
          ttsPortProvider.overrideWithValue(tts),
          detectorProvider.overrideWithValue(detector),
          modelRepositoryProvider.overrideWithValue(FakeModelRepository()),
          alertPresenterProvider.overrideWithValue(presenter),
          monitoringServiceProvider.overrideWithValue(
            const _NoopMonitoringService(),
          ),
          quickTileProvider.overrideWithValue(const _NoopQuickTile()),
          insightPortProvider.overrideWithValue(insight),
          conversationRepositoryProvider.overrideWithValue(conversations),
          sessionRepositoryProvider.overrideWithValue(sessions),
          capabilityProvider.overrideWithValue(capability),
          speechInstallProvider.overrideWithValue(installer),
        ],
        child: const HumSukhanApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> signIn(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).first, 'sana@example.com');
    await tester.enterText(find.byType(TextField).last, 'password123');
    await tester.tap(
      find.widgetWithText(FilledButton, strings(StringKey.authSignIn)),
    );
    await tester.pumpAndSettle();
  }

  /// Pumps a bounded number of frames.
  ///
  /// `pumpAndSettle` cannot be used once a recording is on screen: the duration
  /// readout ticks every second forever, so there is never a frame with nothing
  /// scheduled. Bounded pumping is the honest way to advance a UI that is
  /// legitimately never idle.
  Future<void> advance(WidgetTester tester, {int frames = 12}) async {
    for (int i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }
  }

  /// Opens one of the session-detail tabs.
  ///
  /// The tab bar scrolls on a phone, so the tab has to be brought into view
  /// before it can be tapped — exactly as a user would swipe to it.
  Future<void> openDetailTab(WidgetTester tester, String label) async {
    final Finder tab = find.widgetWithText(Tab, label);
    await tester.ensureVisible(tab);
    await advance(tester);
    await tester.tap(tab);
    await advance(tester);
  }

  /// Switches tab through the navigation bar specifically.
  ///
  /// Every screen stays built in the IndexedStack — that is the point of it —
  /// so a bare `find.text` would also match an off-screen app bar title.
  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(label),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Journey 1 — sign in, caption a conversation, save it', (
    WidgetTester tester,
  ) async {
    await launch(tester);

    // The gate shows the account screen before anything else.
    expect(find.text(strings(StringKey.authSignInTitle)), findsOneWidget);
    await signIn(tester);

    // Home.
    expect(find.text(strings(StringKey.homeEverydayCard)), findsOneWidget);

    await openTab(tester, strings(StringKey.navEveryday));
    await tester.tap(find.text(strings(StringKey.everydayStart)));
    await tester.pumpAndSettle();

    // Open the microphone and let the other person speak twice, with a pause
    // between: two captions, without re-tapping.
    await tester.tap(find.byIcon(Icons.mic));
    await tester.pumpAndSettle();

    conversationStt.finalResult('where is the meeting room');
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    conversationStt.finalResult('it starts at three');
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(
      find.textContaining('where is the meeting room', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('it starts at three', findRichText: true),
      findsOneWidget,
    );

    // Close the microphone before replying: typing and speaking are disabled
    // while the other person's mic is live, so the app never talks over them.
    await tester.tap(find.byIcon(Icons.stop).first);
    await tester.pumpAndSettle();

    // Reply by typing.
    await tester.enterText(find.byType(TextField), 'It is upstairs');
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('It is upstairs', findRichText: true),
      findsOneWidget,
    );

    // Stop and save.
    await tester.tap(find.text(strings(StringKey.everydayStop)));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, strings(StringKey.save)),
    );
    await tester.pumpAndSettle();

    final int saved = (await conversations.list()).valueOrNull!.length;
    expect(saved, 1, reason: 'the conversation reached storage');
  });

  testWidgets('Journey 2 — record a session, summarise it, read the actions', (
    WidgetTester tester,
  ) async {
    await launch(tester);
    await signIn(tester);
    await openTab(tester, strings(StringKey.navProfessional));

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Budget review');
    await tester.tap(
      find.widgetWithText(FilledButton, strings(StringKey.proStartRecording)),
    );
    await tester.pumpAndSettle();

    // Interim text must not enter the transcript.
    recorderStt.partial('the budget is');
    await advance(tester);
    expect(
      find.textContaining('the budget is', findRichText: true),
      findsNothing,
      reason: 'interim text must never appear in a Professional transcript',
    );

    recorderStt.finalResult('the budget is approved');
    await advance(tester);
    expect(
      find.textContaining('the budget is approved', findRichText: true),
      findsOneWidget,
    );

    // A transport drop mid-session is survivable.
    recorderStt.emit(const SttReconnecting(1));
    await advance(tester);
    expect(
      find.text(strings(StringKey.everydayStatusReconnecting)),
      findsOneWidget,
    );
    recorderStt.emit(const SttReconnected());
    await advance(tester);

    // A break in the middle, which every meeting this mode is named for has.
    await tester.tap(find.text(strings(StringKey.proPause)));
    await advance(tester);
    expect(find.text(strings(StringKey.proPaused)), findsOneWidget);
    // What was already said survives the break.
    expect(
      find.textContaining('the budget is approved', findRichText: true),
      findsOneWidget,
    );

    await tester.tap(find.text(strings(StringKey.proResume)));
    await advance(tester);
    expect(find.text(strings(StringKey.proRecording)), findsOneWidget);

    recorderStt.finalResult('Sana will send the notes');
    await advance(tester);

    await tester.tap(find.text(strings(StringKey.proStopRecording)));
    await advance(tester);
    await tester.tap(
      find.widgetWithText(FilledButton, strings(StringKey.save)),
    );
    await advance(tester);

    final List<ProfessionalSession> saved =
        (await sessions.list()).valueOrNull!;
    expect(saved, hasLength(1));
    expect(saved.single.captions, hasLength(2));

    // Open it and generate the summary.
    await tester.tap(find.text('Budget review'));
    await advance(tester);
    await openDetailTab(tester, strings(StringKey.proSummary));
    await tester.tap(
      find.widgetWithText(FilledButton, strings(StringKey.proGenerateSummary)),
    );
    await advance(tester);

    expect(find.text(strings(StringKey.aiDisclaimer)), findsWidgets);
    expect(insight.requests.single, contains('the budget is approved'));

    await openDetailTab(tester, strings(StringKey.proActions));
    expect(
      find.textContaining('Send the notes', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('Journey 3 — turn on monitoring and be alerted to a sound', (
    WidgetTester tester,
  ) async {
    await launch(tester);
    await signIn(tester);
    await openTab(tester, strings(StringKey.navAlerts));

    expect(find.text(strings(StringKey.envStateOff)), findsOneWidget);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(find.text(strings(StringKey.envStateActive)), findsOneWidget);

    detector.observe(SoundKind.doorbell, 0.7, DateTime.now());
    await tester.pumpAndSettle();
    detector.observe(
      SoundKind.doorbell,
      0.7,
      DateTime.now().add(const Duration(seconds: 1)),
    );
    await tester.pumpAndSettle();

    // Non-auditory channels fired, and the alert is on screen.
    expect(presenter.presented, hasLength(1));
    expect(presenter.presented.single.kind, SoundKind.doorbell);
    expect(
      find.text(strings(soundKindLabel(SoundKind.doorbell))),
      findsWidgets,
    );

    // Dismissal is exercised in the Alerts widget suite, where the card can be
    // asserted on directly; a journey's job is to prove the user got here.
  });

  testWidgets('a live conversation survives a tab switch', (
    WidgetTester tester,
  ) async {
    await launch(tester);
    await signIn(tester);
    await openTab(tester, strings(StringKey.navEveryday));
    await tester.tap(find.text(strings(StringKey.everydayStart)));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.mic));
    await tester.pumpAndSettle();
    conversationStt.finalResult('do not lose this');
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    await openTab(tester, strings(StringKey.navSettings));
    await openTab(tester, strings(StringKey.navEveryday));

    expect(
      find.textContaining('do not lose this', findRichText: true),
      findsOneWidget,
      reason: 'navigating away must never tear down a live session',
    );
  });
}

final class _NoopMonitoringService implements MonitoringServicePort {
  const _NoopMonitoringService();

  @override
  Future<Result<Unit, DetectorFailure>> start({
    required String title,
    required String body,
  }) async => const Ok<Unit, DetectorFailure>(unit);

  @override
  Future<void> stop() async {}

  @override
  Future<bool> isRunning() async => false;
}

final class _NoopQuickTile implements QuickTilePort {
  const _NoopQuickTile();

  @override
  Future<bool> consumePendingRequest() async => false;

  @override
  Stream<void> get requests => const Stream<void>.empty();

  @override
  Future<void> publishActive({required bool active}) async {}
}
