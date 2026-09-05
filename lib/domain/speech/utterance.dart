import 'package:humsukhan/domain/speech/language_tag.dart';

/// A piece of speech, either recognised from audio or written to be spoken.
final class Utterance {
  /// Creates an utterance.
  const Utterance({required this.text, required this.language});

  /// The words.
  final String text;

  /// The language the words are in.
  final LanguageTag language;

  /// Whether there is anything to say or show.
  bool get isEmpty => text.trim().isEmpty;

  /// Inverse of [isEmpty].
  bool get isNotEmpty => !isEmpty;

  @override
  bool operator ==(Object other) =>
      other is Utterance && other.text == text && other.language == language;

  @override
  int get hashCode => Object.hash(text, language);

  @override
  String toString() => 'Utterance(${language.code}, "$text")';
}
