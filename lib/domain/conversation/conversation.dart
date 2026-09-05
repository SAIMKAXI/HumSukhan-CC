import 'package:humsukhan/domain/conversation/caption.dart';

/// A saved Everyday conversation.
final class Conversation {
  /// Creates a conversation.
  const Conversation({
    required this.id,
    required this.startedAt,
    required this.captions,
    this.endedAt,
    this.title,
  });

  /// Stable identity.
  final String id;

  /// When the conversation began.
  final DateTime startedAt;

  /// When it was stopped, when it has been.
  final DateTime? endedAt;

  /// Every committed caption, in order.
  final List<Caption> captions;

  /// A user-visible label, when one was given.
  final String? title;

  /// How long the conversation ran.
  Duration get duration => (endedAt ?? startedAt).difference(startedAt);

  /// Whether anything was captured.
  bool get isEmpty => captions.isEmpty;

  /// A copy with the given fields replaced.
  Conversation copyWith({
    DateTime? endedAt,
    List<Caption>? captions,
    String? title,
  }) => Conversation(
    id: id,
    startedAt: startedAt,
    endedAt: endedAt ?? this.endedAt,
    captions: captions ?? this.captions,
    title: title ?? this.title,
  );
}
