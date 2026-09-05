import 'package:humsukhan/domain/speech/language_policy.dart';

/// Who produced a caption.
enum CaptionSpeaker {
  /// The person the user is talking to.
  other,

  /// The user.
  own,
}

/// One committed line of a conversation or transcript.
final class Caption {
  /// Creates a caption. [text] is stored as given; classification is derived.
  Caption({
    required this.id,
    required this.text,
    required this.speaker,
    required this.createdAt,
    this.isFinal = true,
  }) : language = LanguagePolicy.classify(text);

  /// Creates a caption with an explicit classification, for rehydration.
  const Caption.withLanguage({
    required this.id,
    required this.text,
    required this.speaker,
    required this.createdAt,
    required this.language,
    this.isFinal = true,
  });

  /// Stable identity. Captions are keyed by this in lists, never by text —
  /// two identical captions are still two captions (design.md §9).
  final String id;

  /// The words.
  final String text;

  /// Who said them.
  final CaptionSpeaker speaker;

  /// When the caption was committed.
  final DateTime createdAt;

  /// What language the text was classified as. Displayed, never silently
  /// corrected (docs/instructions.md §6).
  final CaptionLanguage language;

  /// Whether the recogniser considers this settled. Interim captions are shown
  /// in Everyday mode and hidden in Professional mode.
  final bool isFinal;

  /// A copy with [text] replaced and the classification recomputed.
  Caption withText(String value) => Caption(
    id: id,
    text: value,
    speaker: speaker,
    createdAt: createdAt,
    isFinal: isFinal,
  );

  @override
  bool operator ==(Object other) =>
      other is Caption &&
      other.id == id &&
      other.text == text &&
      other.speaker == speaker &&
      other.createdAt == createdAt &&
      other.isFinal == isFinal;

  @override
  int get hashCode => Object.hash(id, text, speaker, createdAt, isFinal);

  @override
  String toString() => 'Caption($id, ${speaker.name}, "$text")';
}
