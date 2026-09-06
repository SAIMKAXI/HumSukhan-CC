import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/application/common/retention_sweeper.dart';
import 'package:humsukhan/core/failure/failure.dart';
import 'package:humsukhan/domain/conversation/caption.dart';
import 'package:humsukhan/domain/conversation/conversation.dart';
import 'package:humsukhan/domain/conversation/conversation_repository_port.dart';
import 'package:humsukhan/domain/professional/professional_session.dart';
import 'package:humsukhan/domain/speech/language_tag.dart';

import '../../fakes/fake_app_ports.dart';
import '../../fakes/fake_speech_ports.dart';

/// A retention countdown is a promise. This is the half of it that runs on the
/// device; the schema's `purge_expired()` is the other half, and neither is
/// trusted as the only enforcement.
void main() {
  late FakeConversationRepository conversations;
  late FakeSessionRepository sessions;
  late RetentionSweeper sweeper;

  setUp(() {
    conversations = FakeConversationRepository();
    sessions = FakeSessionRepository();
    sweeper = RetentionSweeper(
      conversations: conversations,
      sessions: sessions,
      clock: FakeClock(DateTime.utc(2026, 4, 8)),
    );
  });

  ProfessionalSession session({
    required String id,
    required DateTime startedAt,
    int retentionDays = 7,
  }) => ProfessionalSession(
    id: id,
    title: id,
    type: SessionType.meeting,
    language: LanguageTag.english,
    startedAt: startedAt,
    retentionDays: retentionDays,
  );

  test('expired sessions are removed and current ones are kept', () async {
    await sessions.save(
      session(id: 'old', startedAt: DateTime.utc(2026, 3, 4), retentionDays: 1),
    );
    await sessions.save(
      session(
        id: 'current',
        startedAt: DateTime.utc(2026, 3, 30),
        retentionDays: 15,
      ),
    );

    final int removed = await sweeper.sweep(
      conversationRetention: const Duration(days: 7),
    );

    expect(removed, 1);
    expect((await sessions.list()).valueOrNull!.single.id, 'current');
  });

  test(
    'each session is judged by its own retention, not a shared one',
    () async {
      await sessions.save(
        session(
          id: 'short',
          startedAt: DateTime.utc(2026, 3, 25),
          retentionDays: 1,
        ),
      );
      await sessions.save(
        session(
          id: 'long',
          startedAt: DateTime.utc(2026, 3, 25),
          retentionDays: 15,
        ),
      );

      await sweeper.sweep(conversationRetention: const Duration(days: 7));

      expect((await sessions.list()).valueOrNull!.single.id, 'long');
    },
  );

  test('expired conversations are removed', () async {
    await conversations.save(
      Conversation(
        id: 'old',
        startedAt: DateTime.now().subtract(const Duration(days: 40)),
        captions: const <Caption>[],
      ),
    );

    expect(
      await sweeper.sweep(conversationRetention: const Duration(days: 7)),
      1,
    );
  });

  test('a storage failure is recorded, not thrown', () async {
    sessions.failure = const StorageFailure(FailureCode.storageReadFailed);
    conversations.failure = const StorageFailure(FailureCode.storageReadFailed);

    expect(
      await sweeper.sweep(conversationRetention: const Duration(days: 7)),
      0,
      reason: 'a failed sweep must not stop the app from starting',
    );
  });

  test('nothing to remove is not a failure', () async {
    expect(
      await sweeper.sweep(conversationRetention: const Duration(days: 7)),
      0,
    );
  });
}
