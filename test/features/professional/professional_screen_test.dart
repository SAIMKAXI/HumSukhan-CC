import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/application/professional/session_recorder.dart';
import 'package:humsukhan/core/failure/failure.dart';
import 'package:humsukhan/core/l10n/app_strings.dart';
import 'package:humsukhan/domain/conversation/caption.dart';
import 'package:humsukhan/domain/conversation/conversation_repository_port.dart';
import 'package:humsukhan/domain/professional/professional_session.dart';
import 'package:humsukhan/domain/speech/language_tag.dart';
import 'package:humsukhan/domain/speech/speech_failure.dart';
import 'package:humsukhan/features/professional/live_session_view.dart';
import 'package:humsukhan/features/professional/professional_screen.dart';
import 'package:humsukhan/features/shared/state_views.dart';

import '../../fakes/fake_app_ports.dart';
import '../../support/harness.dart';

void main() {
  ProfessionalSession session({
    String id = 's1',
    String title = 'Standup',
    List<Caption> captions = const <Caption>[],
  }) => ProfessionalSession(
    id: id,
    title: title,
    type: SessionType.meeting,
    language: LanguageTag.english,
    startedAt: DateTime.now(),
    retentionDays: 7,
    captions: captions,
  );

  group('the session list', () {
    testWidgets('shows a loading state before the list arrives', (
      WidgetTester tester,
    ) async {
      final FakeSessionRepository repository = FakeSessionRepository()
        ..delay = const Duration(milliseconds: 50);

      await tester.pumpWidget(
        harness(child: const ProfessionalScreen(), sessions: repository),
      );
      await tester.pump();

      expect(find.byType(LoadingStateView), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.byType(LoadingStateView), findsNothing);
    });

    testWidgets('shows an empty state with nothing recorded', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(harness(child: const ProfessionalScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(EmptyStateView), findsOneWidget);
      expect(find.text(english(StringKey.proNoSessions)), findsOneWidget);
    });

    testWidgets('shows a failure with its reason and a retry', (
      WidgetTester tester,
    ) async {
      final FakeSessionRepository repository = FakeSessionRepository()
        ..failure = const StorageFailure(FailureCode.storageReadFailed);

      await tester.pumpWidget(
        harness(child: const ProfessionalScreen(), sessions: repository),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ErrorStateView), findsOneWidget);
      expect(
        find.text(english.failureMessage(FailureCode.storageReadFailed)),
        findsOneWidget,
      );
      expect(find.text(english(StringKey.retry)), findsOneWidget);
    });

    testWidgets('lists saved sessions with their retention countdown', (
      WidgetTester tester,
    ) async {
      final FakeSessionRepository repository = FakeSessionRepository();
      await repository.save(session(title: 'Budget review'));

      await tester.pumpWidget(
        harness(child: const ProfessionalScreen(), sessions: repository),
      );
      await tester.pumpAndSettle();

      expect(find.text('Budget review'), findsOneWidget);
      expect(find.textContaining('Expires in'), findsOneWidget);
    });
  });

  group('the live recording', () {
    testWidgets('says it is recording and shows the transcript', (
      WidgetTester tester,
    ) async {
      final Caption line = Caption(
        id: 'c1',
        text: 'the budget is approved',
        speaker: CaptionSpeaker.other,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        harness(
          child: LiveSessionView(
            state: RecorderState(
              phase: RecorderPhase.recording,
              session: session(captions: <Caption>[line]),
            ),
            strings: english,
            onStop: () {},
            onSave: () {},
            onDiscard: () {},
            onAddNote: (String _) {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text(english(StringKey.proRecording)), findsOneWidget);
      expect(find.text('the budget is approved'), findsOneWidget);
    });

    testWidgets('an empty transcript explains that only finals are kept', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(
          child: LiveSessionView(
            state: RecorderState(
              phase: RecorderPhase.recording,
              session: session(),
            ),
            strings: english,
            onStop: () {},
            onSave: () {},
            onDiscard: () {},
            onAddNote: (String _) {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text(english(StringKey.proInterimHidden)), findsOneWidget);
    });

    testWidgets('speech in flight is a marker, never the words', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(
          child: LiveSessionView(
            state: RecorderState(
              phase: RecorderPhase.recording,
              session: session(),
              hasSpeechInFlight: true,
            ),
            strings: english,
            onStop: () {},
            onSave: () {},
            onDiscard: () {},
            onAddNote: (String _) {},
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.graphic_eq), findsOneWidget);
    });

    testWidgets('a transport failure is stated with its reason', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(
          child: LiveSessionView(
            state: RecorderState(
              phase: RecorderPhase.failed,
              session: session(),
              failure: const SttFailure(FailureCode.sttTransportLost),
            ),
            strings: english,
            onStop: () {},
            onSave: () {},
            onDiscard: () {},
            onAddNote: (String _) {},
          ),
        ),
      );
      await tester.pump();

      expect(
        find.textContaining(
          english.failureMessage(FailureCode.sttTransportLost),
        ),
        findsOneWidget,
      );
    });

    testWidgets('reconnecting is rendered, not hidden', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(
          child: LiveSessionView(
            state: RecorderState(
              phase: RecorderPhase.reconnecting,
              session: session(),
              reconnectAttempt: 2,
            ),
            strings: english,
            onStop: () {},
            onSave: () {},
            onDiscard: () {},
            onAddNote: (String _) {},
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text(english(StringKey.everydayStatusReconnecting)),
        findsOneWidget,
      );
    });

    testWidgets('a stopped session offers save and discard', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(
          child: LiveSessionView(
            state: RecorderState(
              phase: RecorderPhase.stopped,
              session: session(),
            ),
            strings: english,
            onStop: () {},
            onSave: () {},
            onDiscard: () {},
            onAddNote: (String _) {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text(english(StringKey.save)), findsOneWidget);
      expect(find.text(english(StringKey.discard)), findsOneWidget);
    });
  });

  test('every session type has a label in both languages', () {
    for (final SessionType type in SessionType.values) {
      expect(english(sessionTypeKey(type)), isNotEmpty);
      expect(urdu(sessionTypeKey(type)), isNotEmpty);
      expect(urdu(sessionTypeKey(type)), isNot(english(sessionTypeKey(type))));
    }
  });
}
