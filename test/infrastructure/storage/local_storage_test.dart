import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/core/l10n/app_language.dart';
import 'package:humsukhan/core/result/result.dart';
import 'package:humsukhan/domain/conversation/caption.dart';
import 'package:humsukhan/domain/conversation/conversation.dart';
import 'package:humsukhan/domain/conversation/conversation_repository_port.dart';
import 'package:humsukhan/domain/conversation/turn_policy.dart';
import 'package:humsukhan/domain/professional/professional_session.dart';
import 'package:humsukhan/domain/settings/app_settings.dart';
import 'package:humsukhan/domain/speech/language_tag.dart';
import 'package:humsukhan/infrastructure/storage/key_value_store.dart';
import 'package:humsukhan/infrastructure/storage/local_repositories.dart';
import 'package:humsukhan/infrastructure/storage/prefs_settings_store.dart';
import 'package:humsukhan/infrastructure/storage/user_scope.dart';

void main() {
  late MemoryStore store;

  setUp(() => store = MemoryStore());

  Caption caption(String id, String text) => Caption(
    id: id,
    text: text,
    speaker: CaptionSpeaker.other,
    createdAt: DateTime.utc(2026, 3, 1, 9),
  );

  group('settings round-trip', () {
    test('defaults are returned when nothing is stored', () async {
      final PrefsSettingsStore settings = PrefsSettingsStore(
        store: store,
        scope: const UserScope('u1'),
      );

      expect((await settings.load()).valueOrNull, const AppSettings());
    });

    test('every field survives a save and load', () async {
      final PrefsSettingsStore settings = PrefsSettingsStore(
        store: store,
        scope: const UserScope('u1'),
      );
      const AppSettings written = AppSettings(
        appLanguage: AppLanguage.urdu,
        captionLanguage: LanguageTag.urdu,
        darkMode: true,
        highContrast: true,
        largeText: true,
        captionScale: 1.4,
        pauseThreshold: PauseThreshold.patient,
        retentionDays: 15,
        alertChannels: AlertChannels(haptic: false, torch: true),
        onboardingComplete: true,
        monitoringEnabled: true,
      );

      await settings.save(written);

      expect((await settings.load()).valueOrNull, written);
    });

    test(
      'a corrupt document falls back to defaults rather than crashing',
      () async {
        await store.write('humsukhan.u1.settings', 'not json');
        final PrefsSettingsStore settings = PrefsSettingsStore(
          store: store,
          scope: const UserScope('u1'),
        );

        final Result<AppSettings, StorageFailure> result = await settings
            .load();

        expect(result.isErr, isTrue);
        expect(result.errorOrNull?.remedy, isNotNull);
      },
    );

    test('a stored retention beyond the maximum is clamped on read', () async {
      await store.write('humsukhan.u1.settings', '{"retentionDays": 400}');
      final PrefsSettingsStore settings = PrefsSettingsStore(
        store: store,
        scope: const UserScope('u1'),
      );

      expect((await settings.load()).valueOrNull!.retentionDays, 15);
    });
  });

  group('per-user scoping', () {
    test('two users never see each other\'s settings', () async {
      final PrefsSettingsStore first = PrefsSettingsStore(
        store: store,
        scope: const UserScope('u1'),
      );
      final PrefsSettingsStore second = PrefsSettingsStore(
        store: store,
        scope: const UserScope('u2'),
      );

      await first.save(const AppSettings(darkMode: true));

      expect((await second.load()).valueOrNull!.darkMode, isFalse);
    });

    test('two users never see each other\'s conversations', () async {
      final LocalConversationRepository first = LocalConversationRepository(
        store: store,
        scope: const UserScope('u1'),
      );
      final LocalConversationRepository second = LocalConversationRepository(
        store: store,
        scope: const UserScope('u2'),
      );

      await first.save(
        Conversation(
          id: 'c1',
          startedAt: DateTime.utc(2026, 3, 4),
          captions: <Caption>[caption('x', 'private')],
        ),
      );

      expect((await second.list()).valueOrNull, isEmpty);
      expect((await first.list()).valueOrNull, hasLength(1));
    });

    test('a storage key always names its owner', () {
      expect(const UserScope('u1').key('settings'), 'humsukhan.u1.settings');
      expect(UserScope.anonymous.key('settings'), contains('anonymous'));
    });
  });

  group('conversations', () {
    late LocalConversationRepository repository;

    setUp(
      () => repository = LocalConversationRepository(
        store: store,
        scope: const UserScope('u1'),
      ),
    );

    test('captions survive a round-trip with their text intact', () async {
      await repository.save(
        Conversation(
          id: 'c1',
          startedAt: DateTime.utc(2026, 3, 4),
          captions: <Caption>[
            caption('a', 'where is the room'),
            caption('b', 'میٹنگ کہاں ہے'),
          ],
        ),
      );

      final Conversation restored =
          (await repository.list()).valueOrNull!.single;

      expect(restored.captions.map((Caption c) => c.text), <String>[
        'where is the room',
        'میٹنگ کہاں ہے',
      ]);
    });

    test('saving twice replaces rather than duplicates', () async {
      final Conversation conversation = Conversation(
        id: 'c1',
        startedAt: DateTime.utc(2026, 3, 4),
        captions: <Caption>[caption('a', 'one')],
      );
      await repository.save(conversation);
      await repository.save(
        conversation.copyWith(captions: <Caption>[caption('a', 'two')]),
      );

      final List<Conversation> all = (await repository.list()).valueOrNull!;
      expect(all, hasLength(1));
      expect(all.single.captions.single.text, 'two');
    });

    test('newest first', () async {
      await repository.save(
        Conversation(
          id: 'old',
          startedAt: DateTime.utc(2026, 1, 8),
          captions: const <Caption>[],
        ),
      );
      await repository.save(
        Conversation(
          id: 'new',
          startedAt: DateTime.utc(2026, 3, 4),
          captions: const <Caption>[],
        ),
      );

      expect((await repository.list()).valueOrNull!.first.id, 'new');
    });

    test('deleting removes exactly one', () async {
      await repository.save(
        Conversation(
          id: 'c1',
          startedAt: DateTime.utc(2026, 3, 4),
          captions: const <Caption>[],
        ),
      );
      await repository.delete('c1');

      expect((await repository.list()).valueOrNull, isEmpty);
    });

    test('purging removes only what has expired', () async {
      await repository.save(
        Conversation(
          id: 'old',
          startedAt: DateTime.now().subtract(const Duration(days: 30)),
          captions: const <Caption>[],
        ),
      );
      await repository.save(
        Conversation(
          id: 'fresh',
          startedAt: DateTime.now(),
          captions: const <Caption>[],
        ),
      );

      final Result<int, StorageFailure> purged = await repository.purgeExpired(
        const Duration(days: 7),
      );

      expect(purged.valueOrNull, 1);
      expect((await repository.list()).valueOrNull!.single.id, 'fresh');
    });
  });

  group('sessions', () {
    late LocalSessionRepository repository;

    setUp(
      () => repository = LocalSessionRepository(
        store: store,
        scope: const UserScope('u1'),
      ),
    );

    ProfessionalSession session({
      String id = 's1',
      DateTime? startedAt,
      int retentionDays = 7,
    }) => ProfessionalSession(
      id: id,
      title: 'Standup',
      type: SessionType.meeting,
      language: LanguageTag.urdu,
      startedAt: startedAt ?? DateTime.utc(2026, 3, 4),
      retentionDays: retentionDays,
      captions: <Caption>[caption('a', 'the budget is approved')],
    );

    test('a session survives a round-trip', () async {
      await repository.save(session());

      final ProfessionalSession restored = (await repository.find('s1'))
          .valueOrNull!;

      expect(restored.title, 'Standup');
      expect(restored.language, LanguageTag.urdu);
      expect(restored.type, SessionType.meeting);
      expect(restored.captions.single.text, 'the budget is approved');
    });

    test('a missing session is null, not a failure', () async {
      final Result<ProfessionalSession?, StorageFailure> result =
          await repository.find('nope');

      expect(result.isOk, isTrue);
      expect(result.valueOrNull, isNull);
    });

    test('purging honours each session\'s own retention', () async {
      await repository.save(
        session(
          id: 'expired',
          startedAt: DateTime.utc(2026, 3, 4),
          retentionDays: 1,
        ),
      );
      await repository.save(
        session(
          id: 'kept',
          startedAt: DateTime.utc(2026, 3, 4),
          retentionDays: 15,
        ),
      );

      final Result<int, StorageFailure> purged = await repository.purgeExpired(
        DateTime.utc(2026, 3, 5),
      );

      expect(purged.valueOrNull, 1);
      expect((await repository.list()).valueOrNull!.single.id, 'kept');
    });
  });
}
