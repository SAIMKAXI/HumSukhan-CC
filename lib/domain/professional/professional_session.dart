import 'package:humsukhan/domain/conversation/caption.dart';
import 'package:humsukhan/domain/professional/insight.dart';
import 'package:humsukhan/domain/speech/language_tag.dart';

/// What kind of thing is being recorded.
enum SessionType {
  /// A meeting.
  meeting,

  /// A lecture.
  lecture,

  /// A class.
  classroom;

  /// Parses a stored name, defaulting to [SessionType.meeting].
  static SessionType fromName(String? name) => SessionType.values.firstWhere(
    (SessionType t) => t.name == name,
    orElse: () => SessionType.meeting,
  );
}

/// A long-form capture: a meeting, lecture or class.
final class ProfessionalSession {
  /// Creates a session.
  const ProfessionalSession({
    required this.id,
    required this.title,
    required this.type,
    required this.language,
    required this.startedAt,
    required this.retentionDays,
    this.endedAt,
    this.captions = const <Caption>[],
    this.insight,
  });

  /// Stable identity.
  final String id;

  /// What the user called it.
  final String title;

  /// Meeting, lecture or class.
  final SessionType type;

  /// The caption language chosen when the session was created.
  final LanguageTag language;

  /// When recording began.
  final DateTime startedAt;

  /// When recording stopped, when it has.
  final DateTime? endedAt;

  /// How long this session is kept.
  final int retentionDays;

  /// The transcript. Only finalised captions ever enter this list — interim
  /// text must never flicker into a Professional transcript (design.md §5.6).
  final List<Caption> captions;

  /// The generated summary, once there is one.
  final Insight? insight;

  /// Whether recording is still running.
  bool get isRecording => endedAt == null;

  /// How long the session ran, or has run so far when [now] is given.
  Duration durationAt(DateTime now) => (endedAt ?? now).difference(startedAt);

  /// The transcript as plain text, one caption per line.
  String get transcriptText => captions
      .map((Caption c) => c.text)
      .where((String t) => t.trim().isNotEmpty)
      .join('\n');

  /// Rough word count of the transcript.
  int get wordCount => transcriptText
      .split(RegExp(r'\s+'))
      .where((String w) => w.isNotEmpty)
      .length;

  /// A copy with the given fields replaced.
  ProfessionalSession copyWith({
    String? title,
    DateTime? endedAt,
    List<Caption>? captions,
    Insight? insight,
    int? retentionDays,
  }) => ProfessionalSession(
    id: id,
    title: title ?? this.title,
    type: type,
    language: language,
    startedAt: startedAt,
    endedAt: endedAt ?? this.endedAt,
    retentionDays: retentionDays ?? this.retentionDays,
    captions: captions ?? this.captions,
    insight: insight ?? this.insight,
  );
}
