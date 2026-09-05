import 'dart:convert';

import 'package:humsukhan/core/failure/failure.dart';
import 'package:humsukhan/core/logging/app_logger.dart';
import 'package:humsukhan/core/result/result.dart';
import 'package:humsukhan/domain/conversation/caption.dart';
import 'package:humsukhan/domain/conversation/conversation.dart';
import 'package:humsukhan/domain/conversation/conversation_repository_port.dart';
import 'package:humsukhan/domain/professional/insight.dart';
import 'package:humsukhan/domain/professional/professional_session.dart';
import 'package:humsukhan/domain/professional/session_repository_port.dart';
import 'package:humsukhan/domain/speech/language_tag.dart';
import 'package:humsukhan/infrastructure/storage/key_value_store.dart';
import 'package:humsukhan/infrastructure/storage/user_scope.dart';

/// JSON encoding for the entities the local stores persist.
abstract final class EntityCodec {
  /// Encodes a caption.
  static Map<String, Object?> captionToJson(Caption caption) =>
      <String, Object?>{
        'id': caption.id,
        'text': caption.text,
        'speaker': caption.speaker.name,
        'createdAt': caption.createdAt.toIso8601String(),
        'language': caption.language.name,
        'isFinal': caption.isFinal,
      };

  /// Decodes a caption, recomputing the classification rather than trusting a
  /// stored value that a policy change may have made wrong.
  static Caption captionFromJson(Map<String, Object?> json) => Caption(
    id: json['id'] as String? ?? '',
    text: json['text'] as String? ?? '',
    speaker: json['speaker'] == CaptionSpeaker.own.name
        ? CaptionSpeaker.own
        : CaptionSpeaker.other,
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    isFinal: json['isFinal'] as bool? ?? true,
  );

  /// Encodes a conversation.
  static Map<String, Object?> conversationToJson(Conversation c) =>
      <String, Object?>{
        'id': c.id,
        'startedAt': c.startedAt.toIso8601String(),
        'endedAt': c.endedAt?.toIso8601String(),
        'title': c.title,
        'captions': c.captions.map(captionToJson).toList(growable: false),
      };

  /// Decodes a conversation.
  static Conversation conversationFromJson(Map<String, Object?> json) =>
      Conversation(
        id: json['id'] as String? ?? '',
        startedAt:
            DateTime.tryParse(json['startedAt'] as String? ?? '') ??
            DateTime.now(),
        endedAt: DateTime.tryParse(json['endedAt'] as String? ?? ''),
        title: json['title'] as String?,
        captions: _captions(json['captions']),
      );

  /// Encodes an insight.
  static Map<String, Object?> insightToJson(Insight insight) =>
      <String, Object?>{
        'summary': insight.summary,
        'generatedAt': insight.generatedAt.toIso8601String(),
        'keyPoints': insight.keyPoints,
        'people': insight.people,
        'actionItems': insight.actionItems
            .map(
              (ActionItem a) => <String, Object?>{
                'description': a.description,
                'owner': a.owner,
                'deadline': a.deadline,
              },
            )
            .toList(growable: false),
      };

  /// Decodes an insight.
  static Insight insightFromJson(Map<String, Object?> json) => Insight(
    summary: json['summary'] as String? ?? '',
    generatedAt:
        DateTime.tryParse(json['generatedAt'] as String? ?? '') ??
        DateTime.now(),
    keyPoints: _strings(json['keyPoints']),
    people: _strings(json['people']),
    actionItems: (json['actionItems'] is List<Object?>)
        ? (json['actionItems']! as List<Object?>)
              .whereType<Map<String, Object?>>()
              .map(
                (Map<String, Object?> a) => ActionItem(
                  description: a['description'] as String? ?? '',
                  owner: a['owner'] as String?,
                  deadline: a['deadline'] as String?,
                ),
              )
              .toList(growable: false)
        : const <ActionItem>[],
  );

  /// Encodes a session.
  static Map<String, Object?> sessionToJson(ProfessionalSession s) =>
      <String, Object?>{
        'id': s.id,
        'title': s.title,
        'type': s.type.name,
        'language': s.language.code,
        'startedAt': s.startedAt.toIso8601String(),
        'endedAt': s.endedAt?.toIso8601String(),
        'retentionDays': s.retentionDays,
        'captions': s.captions.map(captionToJson).toList(growable: false),
        'insight': s.insight == null ? null : insightToJson(s.insight!),
      };

  /// Decodes a session.
  static ProfessionalSession sessionFromJson(Map<String, Object?> json) {
    final Object? insight = json['insight'];
    final Object? retention = json['retentionDays'];
    return ProfessionalSession(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      type: SessionType.fromName(json['type'] as String?),
      language:
          LanguageTag.tryParse(json['language'] as String?) ??
          LanguageTag.english,
      startedAt:
          DateTime.tryParse(json['startedAt'] as String? ?? '') ??
          DateTime.now(),
      endedAt: DateTime.tryParse(json['endedAt'] as String? ?? ''),
      retentionDays: retention is num ? retention.toInt() : 7,
      captions: _captions(json['captions']),
      insight: insight is Map<String, Object?>
          ? insightFromJson(insight)
          : null,
    );
  }

  static List<Caption> _captions(Object? value) => value is List<Object?>
      ? value
            .whereType<Map<String, Object?>>()
            .map(captionFromJson)
            .toList(growable: false)
      : const <Caption>[];

  static List<String> _strings(Object? value) => value is List<Object?>
      ? value.whereType<String>().toList(growable: false)
      : const <String>[];
}

/// Conversations kept on the device, scoped to one account.
final class LocalConversationRepository implements ConversationRepositoryPort {
  /// Creates a repository.
  LocalConversationRepository({
    required KeyValueStore store,
    required UserScope scope,
    AppLogger logger = const SilentLogger(),
  }) : _store = store,
       _scope = scope,
       _logger = logger;

  final KeyValueStore _store;
  final UserScope _scope;
  final AppLogger _logger;

  String get _key => _scope.key('conversations');

  @override
  Future<Result<List<Conversation>, StorageFailure>> list() async {
    try {
      final List<Conversation> items = await _read();
      items.sort(
        (Conversation a, Conversation b) => b.startedAt.compareTo(a.startedAt),
      );
      return Ok<List<Conversation>, StorageFailure>(
        List<Conversation>.unmodifiable(items),
      );
    } on Object catch (error, stackTrace) {
      return _readFailure<List<Conversation>>(error, stackTrace);
    }
  }

  @override
  Future<Result<Unit, StorageFailure>> save(Conversation conversation) async {
    try {
      final List<Conversation> items = await _read()
        ..removeWhere((Conversation c) => c.id == conversation.id)
        ..add(conversation);
      await _write(items);
      return const Ok<Unit, StorageFailure>(unit);
    } on Object catch (error, stackTrace) {
      return _writeFailure<Unit>(error, stackTrace);
    }
  }

  @override
  Future<Result<Unit, StorageFailure>> delete(String id) async {
    try {
      final List<Conversation> items = await _read()
        ..removeWhere((Conversation c) => c.id == id);
      await _write(items);
      return const Ok<Unit, StorageFailure>(unit);
    } on Object catch (error, stackTrace) {
      return _writeFailure<Unit>(error, stackTrace);
    }
  }

  @override
  Future<Result<int, StorageFailure>> purgeExpired(Duration retention) async {
    try {
      final DateTime cutoff = DateTime.now().subtract(retention);
      final List<Conversation> items = await _read();
      final int before = items.length;
      items.removeWhere((Conversation c) => c.startedAt.isBefore(cutoff));
      if (items.length != before) await _write(items);
      return Ok<int, StorageFailure>(before - items.length);
    } on Object catch (error, stackTrace) {
      return _writeFailure<int>(error, stackTrace);
    }
  }

  Future<List<Conversation>> _read() async {
    final String? raw = await _store.read(_key);
    if (raw == null) return <Conversation>[];
    final Object? decoded = jsonDecode(raw);
    if (decoded is! List<Object?>) return <Conversation>[];
    return decoded
        .whereType<Map<String, Object?>>()
        .map(EntityCodec.conversationFromJson)
        .toList();
  }

  Future<void> _write(List<Conversation> items) => _store.write(
    _key,
    jsonEncode(
      items.map(EntityCodec.conversationToJson).toList(growable: false),
    ),
  );

  Result<T, StorageFailure> _readFailure<T>(Object error, StackTrace trace) {
    _logger.log(
      LogLevel.error,
      'conversations',
      'read failed',
      error: error,
      stackTrace: trace,
    );
    return Err<T, StorageFailure>(
      StorageFailure(FailureCode.storageReadFailed, detail: '$error'),
    );
  }

  Result<T, StorageFailure> _writeFailure<T>(Object error, StackTrace trace) {
    _logger.log(
      LogLevel.error,
      'conversations',
      'write failed',
      error: error,
      stackTrace: trace,
    );
    return Err<T, StorageFailure>(
      StorageFailure(FailureCode.storageWriteFailed, detail: '$error'),
    );
  }
}

/// Professional sessions kept on the device, scoped to one account.
final class LocalSessionRepository implements SessionRepositoryPort {
  /// Creates a repository.
  LocalSessionRepository({
    required KeyValueStore store,
    required UserScope scope,
    AppLogger logger = const SilentLogger(),
  }) : _store = store,
       _scope = scope,
       _logger = logger;

  final KeyValueStore _store;
  final UserScope _scope;
  final AppLogger _logger;

  String get _key => _scope.key('sessions');

  @override
  Future<Result<List<ProfessionalSession>, StorageFailure>> list() async {
    try {
      final List<ProfessionalSession> items = await _read();
      items.sort(
        (ProfessionalSession a, ProfessionalSession b) =>
            b.startedAt.compareTo(a.startedAt),
      );
      return Ok<List<ProfessionalSession>, StorageFailure>(
        List<ProfessionalSession>.unmodifiable(items),
      );
    } on Object catch (error, stackTrace) {
      return _failure<List<ProfessionalSession>>(
        FailureCode.storageReadFailed,
        error,
        stackTrace,
      );
    }
  }

  @override
  Future<Result<ProfessionalSession?, StorageFailure>> find(String id) async {
    final Result<List<ProfessionalSession>, StorageFailure> all = await list();
    return all.map((List<ProfessionalSession> items) {
      for (final ProfessionalSession session in items) {
        if (session.id == id) return session;
      }
      return null;
    });
  }

  @override
  Future<Result<Unit, StorageFailure>> save(ProfessionalSession session) async {
    try {
      final List<ProfessionalSession> items = await _read()
        ..removeWhere((ProfessionalSession s) => s.id == session.id)
        ..add(session);
      await _write(items);
      return const Ok<Unit, StorageFailure>(unit);
    } on Object catch (error, stackTrace) {
      return _failure<Unit>(FailureCode.storageWriteFailed, error, stackTrace);
    }
  }

  @override
  Future<Result<Unit, StorageFailure>> delete(String id) async {
    try {
      final List<ProfessionalSession> items = await _read()
        ..removeWhere((ProfessionalSession s) => s.id == id);
      await _write(items);
      return const Ok<Unit, StorageFailure>(unit);
    } on Object catch (error, stackTrace) {
      return _failure<Unit>(FailureCode.storageWriteFailed, error, stackTrace);
    }
  }

  @override
  Future<Result<int, StorageFailure>> purgeExpired(DateTime now) async {
    try {
      final List<ProfessionalSession> items = await _read();
      final int before = items.length;
      items.removeWhere(
        (ProfessionalSession s) =>
            !s.startedAt.add(Duration(days: s.retentionDays)).isAfter(now),
      );
      if (items.length != before) await _write(items);
      return Ok<int, StorageFailure>(before - items.length);
    } on Object catch (error, stackTrace) {
      return _failure<int>(FailureCode.storageWriteFailed, error, stackTrace);
    }
  }

  Future<List<ProfessionalSession>> _read() async {
    final String? raw = await _store.read(_key);
    if (raw == null) return <ProfessionalSession>[];
    final Object? decoded = jsonDecode(raw);
    if (decoded is! List<Object?>) return <ProfessionalSession>[];
    return decoded
        .whereType<Map<String, Object?>>()
        .map(EntityCodec.sessionFromJson)
        .toList();
  }

  Future<void> _write(List<ProfessionalSession> items) => _store.write(
    _key,
    jsonEncode(items.map(EntityCodec.sessionToJson).toList(growable: false)),
  );

  Result<T, StorageFailure> _failure<T>(
    FailureCode code,
    Object error,
    StackTrace trace,
  ) {
    _logger.log(
      LogLevel.error,
      'sessions',
      'storage failed',
      error: error,
      stackTrace: trace,
    );
    return Err<T, StorageFailure>(StorageFailure(code, detail: '$error'));
  }
}
