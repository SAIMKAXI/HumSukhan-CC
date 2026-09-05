/// A language a recogniser or synthesiser can be asked for.
///
/// Deliberately closed: English and Urdu only. There is no Hindi member,
/// because substituting Hindi for Urdu at any layer is forbidden
/// (docs/instructions.md §6).
enum LanguageTag {
  /// English as spoken in Pakistan/India/UK/US — the recogniser locale is
  /// resolved by the adapter, not here.
  english('en'),

  /// Urdu in Urdu script.
  urdu('ur');

  const LanguageTag(this.code);

  /// BCP 47 primary subtag.
  final String code;

  /// The BCP 47 tag an engine is asked for, with a sensible regional default.
  String get preferredLocale => switch (this) {
    LanguageTag.english => 'en-US',
    LanguageTag.urdu => 'ur-PK',
  };

  /// Fallback locales, in order, when [preferredLocale] is unavailable.
  List<String> get fallbackLocales => switch (this) {
    LanguageTag.english => const <String>['en-GB', 'en-IN', 'en'],
    // ur-IN is a legitimate Urdu locale. hi-IN is never a fallback for Urdu.
    LanguageTag.urdu => const <String>['ur-IN', 'ur'],
  };

  /// Parses a locale string. Returns `null` for anything that is not English or
  /// Urdu — including `hi`, which must never resolve to [LanguageTag.urdu].
  static LanguageTag? tryParse(String? locale) {
    if (locale == null || locale.isEmpty) return null;
    final String primary = locale.toLowerCase().split(RegExp('[-_]')).first;
    return switch (primary) {
      'en' => LanguageTag.english,
      'ur' => LanguageTag.urdu,
      _ => null,
    };
  }
}
