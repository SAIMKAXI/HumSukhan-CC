import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/application/conversation/conversation_session_state.dart';
import 'package:humsukhan/core/failure/failure.dart';
import 'package:humsukhan/core/l10n/app_language.dart';
import 'package:humsukhan/core/l10n/app_strings.dart';
import 'package:humsukhan/domain/conversation/caption.dart';
import 'package:humsukhan/domain/conversation/turn_policy.dart';
import 'package:humsukhan/domain/speech/speech_failure.dart';
import 'package:humsukhan/features/conversation/conversation_composer.dart';
import 'package:humsukhan/features/conversation/conversation_screen.dart';
import 'package:humsukhan/features/conversation/speaker_controls.dart';
import 'package:humsukhan/features/shared/caption_bubble.dart';

import '../../fakes/fake_speech_ports.dart';
import '../../support/harness.dart';

void main() {
  Caption caption(String id, String text) => Caption(
    id: id,
    text: text,
    speaker: CaptionSpeaker.other,
    createdAt: DateTime.utc(2026, 3, 4),
  );

  group('the status line names every phase', () {
    test('idle says the microphone is off', () {
      expect(
        SpeakerControls.statusKey(const ConversationSessionState()),
        StringKey.everydayStatusIdle,
      );
    });

    test('starting says so rather than showing nothing', () {
      expect(
        SpeakerControls.statusKey(
          const ConversationSessionState(phase: ListeningPhase.starting),
        ),
        StringKey.everydayStatusStarting,
      );
    });

    test('an open microphone with nothing captured says listening', () {
      expect(
        SpeakerControls.statusKey(
          const ConversationSessionState(phase: ListeningPhase.listening),
        ),
        StringKey.everydayStatusListening,
      );
    });

    test('after a commit it says the microphone is still open', () {
      final ConversationSessionState state = ConversationSessionState(
        phase: ListeningPhase.listening,
        captions: <Caption>[caption('a', 'first sentence')],
      );

      expect(
        SpeakerControls.statusKey(state),
        StringKey.everydayStatusPaused,
        reason: 'a pause ended the utterance, not the session',
      );
      expect(english(StringKey.everydayStatusPaused), contains('speak again'));
    });

    test('reconnecting and failed are rendered phases', () {
      expect(
        SpeakerControls.statusKey(
          const ConversationSessionState(phase: ListeningPhase.reconnecting),
        ),
        StringKey.everydayStatusReconnecting,
      );
      expect(
        SpeakerControls.statusKey(
          const ConversationSessionState(phase: ListeningPhase.failed),
        ),
        StringKey.everydayStatusFailed,
      );
    });

    test('every phase has a status line in both languages', () {
      for (final ListeningPhase phase in ListeningPhase.values) {
        final StringKey key = SpeakerControls.statusKey(
          ConversationSessionState(phase: phase),
        );
        expect(english(key), isNotEmpty);
        expect(urdu(key), isNotEmpty);
      }
    });

    test('every pause threshold has a label in both languages', () {
      for (final PauseThreshold threshold in PauseThreshold.values) {
        final StringKey key = SpeakerControls.thresholdKey(threshold);
        expect(english(key), isNotEmpty);
        expect(urdu(key), isNotEmpty);
      }
    });
  });

  group('the idle screen', () {
    testWidgets('offers the privacy notice and a way to start', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(harness(child: const ConversationScreen()));
      await settle(tester);

      expect(
        find.text(english(StringKey.everydayPrivacyNotice)),
        findsOneWidget,
      );
      expect(find.text(english(StringKey.everydayStart)), findsOneWidget);
    });

    testWidgets('renders in Urdu when the app language is Urdu', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(child: const ConversationScreen(), language: AppLanguage.urdu),
      );
      await settle(tester);

      expect(find.text(urdu(StringKey.everydayStart)), findsOneWidget);
    });
  });

  group('an active conversation', () {
    testWidgets('shows the empty state before anything is captured', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(harness(child: const ConversationScreen()));
      await settle(tester);

      await tester.tap(find.text(english(StringKey.everydayStart)));
      await tester.pump();

      expect(find.text(english(StringKey.everydayNoCaptions)), findsOneWidget);
    });

    testWidgets('a typed reply becomes a caption on screen', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(harness(child: const ConversationScreen()));
      await settle(tester);
      await tester.tap(find.text(english(StringKey.everydayStart)));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'I am here');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();

      expect(find.byType(SpeakableCaptionBubble), findsOneWidget);
      expect(find.text('I am here'), findsOneWidget);
    });

    testWidgets('the send button is disabled with nothing typed', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(harness(child: const ConversationScreen()));
      await settle(tester);
      await tester.tap(find.text(english(StringKey.everydayStart)));
      await tester.pump();

      final IconButton send = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.send),
          matching: find.byType(IconButton),
        ),
      );
      expect(send.onPressed, isNull);
    });

    testWidgets('quick replies are offered', (WidgetTester tester) async {
      await tester.pumpWidget(harness(child: const ConversationScreen()));
      await settle(tester);
      await tester.tap(find.text(english(StringKey.everydayStart)));
      await tester.pump();

      expect(find.byType(ConversationComposer), findsOneWidget);
      expect(find.text(english(StringKey.quickReplyThanks)), findsOneWidget);
    });

    testWidgets('a recognition failure is on screen with its remedy', (
      WidgetTester tester,
    ) async {
      final FakeSttPort stt = FakeSttPort()
        ..failOnStart = const SttFailure(
          FailureCode.microphonePermissionDenied,
        );

      await tester.pumpWidget(
        harness(child: const ConversationScreen(), conversationStt: stt),
      );
      await settle(tester);
      await tester.tap(find.text(english(StringKey.everydayStart)));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.mic));
      await tester.pump();
      await tester.pump();

      expect(
        find.textContaining(
          english.failureMessage(FailureCode.microphonePermissionDenied),
          findRichText: true,
        ),
        findsWidgets,
      );
    });
  });

  group('the save decision', () {
    testWidgets('save is disabled when nothing was captured', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(harness(child: const ConversationScreen()));
      await settle(tester);
      await tester.tap(find.text(english(StringKey.everydayStart)));
      await tester.pump();

      await tester.tap(find.text(english(StringKey.everydayStop)));
      await tester.pump();
      await tester.pump();

      expect(find.text(english(StringKey.everydaySaveTitle)), findsOneWidget);
      final FilledButton save = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, english(StringKey.save)),
      );
      expect(save.onPressed, isNull);
    });

    testWidgets('continuing returns to the conversation', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(harness(child: const ConversationScreen()));
      await settle(tester);
      await tester.tap(find.text(english(StringKey.everydayStart)));
      await tester.pump();
      await tester.tap(find.text(english(StringKey.everydayStop)));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text(english(StringKey.continueLabel)));
      await tester.pump();

      expect(find.byType(ConversationComposer), findsOneWidget);
    });
  });
}
