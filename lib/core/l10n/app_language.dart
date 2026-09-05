import 'dart:ui' show Locale, TextDirection;

/// The two languages HumSukhan supports. There is no third option and no
/// automatic substitution: Hindi is never shown in place of Urdu.
enum AppLanguage {
  /// English, left to right, Latin script.
  english('en', TextDirection.ltr),

  /// Urdu, right to left, Nastaliq script.
  urdu('ur', TextDirection.rtl);

  const AppLanguage(this.code, this.direction);

  /// BCP 47 language subtag.
  final String code;

  /// Reading direction for text written in this language.
  final TextDirection direction;

  /// The Flutter locale for this language.
  Locale get locale => Locale(code);

  /// Parses a stored or platform code, defaulting to [AppLanguage.english].
  ///
  /// Only `en` and `ur` are recognised. Anything else — including `hi` — falls
  /// back to English rather than being coerced into Urdu.
  static AppLanguage fromCode(String? code) {
    if (code == null) return AppLanguage.english;
    final String normalised = code.toLowerCase().split(RegExp('[-_]')).first;
    return switch (normalised) {
      'ur' => AppLanguage.urdu,
      _ => AppLanguage.english,
    };
  }
}
