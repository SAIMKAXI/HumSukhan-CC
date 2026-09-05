/// Pure language classification, normalisation and run splitting.
///
/// No Flutter, no plugins, no I/O — every rule here is a unit test. This module
/// decides what language a piece of text is *in*; it never rewrites the user's
/// classification silently (docs/instructions.md §6).
library;

/// What a piece of text was classified as. Shown to the user as-is; there is no
/// `auto` member, because `Auto` is an internal mode name and must never reach
/// UI copy (design.md §9).
enum CaptionLanguage {
  /// Latin script, not recognisable as Roman Urdu.
  english,

  /// Urdu script.
  urdu,

  /// Urdu written in Latin letters.
  romanUrdu,

  /// Both scripts present in the same text.
  mixed,

  /// Nothing to classify yet.
  undetermined,
}

/// Reading direction of a run of text. Domain-owned so this file stays free of
/// `dart:ui`.
enum ReadingDirection {
  /// Left to right.
  leftToRight,

  /// Right to left.
  rightToLeft,
}

/// A contiguous stretch of text that shares one direction.
final class TextRun {
  /// Creates a run.
  const TextRun(this.text, this.direction);

  /// The characters in this run.
  final String text;

  /// How this run reads.
  final ReadingDirection direction;

  @override
  bool operator ==(Object other) =>
      other is TextRun && other.text == text && other.direction == direction;

  @override
  int get hashCode => Object.hash(text, direction);

  @override
  String toString() => 'TextRun(${direction.name}, "$text")';
}

/// Classification, normalisation and direction rules for HumSukhan text.
abstract final class LanguagePolicy {
  // Disjoint script ranges. Arabic covers the Urdu letters, its presentation
  // forms and the extended Arabic blocks Urdu uses.
  static bool _isArabic(int c) =>
      (c >= 0x0600 && c <= 0x06FF) ||
      (c >= 0x0750 && c <= 0x077F) ||
      (c >= 0x08A0 && c <= 0x08FF) ||
      (c >= 0xFB50 && c <= 0xFDFF) ||
      (c >= 0xFE70 && c <= 0xFEFF);

  static bool _isDevanagari(int c) =>
      (c >= 0x0900 && c <= 0x097F) ||
      (c >= 0xA8E0 && c <= 0xA8FF) ||
      (c >= 0x1CD0 && c <= 0x1CFF);

  static bool _isLatinLetter(int c) =>
      (c >= 0x41 && c <= 0x5A) ||
      (c >= 0x61 && c <= 0x7A) ||
      (c >= 0x00C0 && c <= 0x024F);

  /// Whether [text] contains any Urdu-script character.
  static bool hasUrduScript(String text) => text.runes.any(_isArabic);

  /// Whether [text] contains any Latin letter.
  static bool hasLatinScript(String text) => text.runes.any(_isLatinLetter);

  /// Whether [text] contains any Devanagari character.
  static bool hasDevanagari(String text) => text.runes.any(_isDevanagari);

  /// Removes every Devanagari character from [text].
  ///
  /// Recognisers occasionally return Devanagari for Urdu audio. It is stripped
  /// **before** any routing or display and is never treated as Urdu
  /// (docs/instructions.md §6). Whitespace left behind is collapsed so the
  /// result does not carry the holes.
  static String stripDevanagari(String text) {
    if (!hasDevanagari(text)) return text;
    final StringBuffer buffer = StringBuffer();
    for (final int rune in text.runes) {
      if (!_isDevanagari(rune)) buffer.writeCharCode(rune);
    }
    return collapseWhitespace(buffer.toString());
  }

  /// Trims and collapses runs of whitespace to a single space.
  static String collapseWhitespace(String text) =>
      text.replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Classifies [text].
  ///
  /// Devanagari is stripped first, so text that was purely Devanagari
  /// classifies as [CaptionLanguage.undetermined] rather than as Urdu.
  static CaptionLanguage classify(String text) {
    final String cleaned = stripDevanagari(text);
    if (cleaned.trim().isEmpty) return CaptionLanguage.undetermined;

    final bool urduScript = hasUrduScript(cleaned);
    final bool latin = hasLatinScript(cleaned);

    if (urduScript && latin) return CaptionLanguage.mixed;
    if (urduScript) return CaptionLanguage.urdu;
    if (!latin) return CaptionLanguage.undetermined;
    return isRomanUrdu(cleaned)
        ? CaptionLanguage.romanUrdu
        : CaptionLanguage.english;
  }

  /// Whether Latin-script [text] reads as Urdu written in Latin letters.
  ///
  /// A single marker word is not enough — "main" and "hai" both occur in
  /// English. The decision is a share of the words, with a lower bar for very
  /// short utterances where there is little else to go on.
  static bool isRomanUrdu(String text) {
    final List<String> words = _words(text);
    if (words.isEmpty) return false;
    final int markers = words.where(_romanUrduMarkers.contains).length;
    if (markers == 0) return false;
    if (words.length <= 2) return markers == words.length;
    return markers / words.length >= 0.34;
  }

  static List<String> _words(String text) => text
      .toLowerCase()
      .split(RegExp(r"[^a-zÀ-ɏ']+"))
      .where((String w) => w.isNotEmpty)
      .toList(growable: false);

  /// Rewrites Roman Urdu [text] into Urdu script.
  ///
  /// Known words come from a lexicon; anything else is transliterated by rule.
  /// Text that is not Roman Urdu is returned unchanged — this never guesses at
  /// English.
  static String normaliseRomanUrduToScript(String text) {
    final String cleaned = stripDevanagari(text);
    if (!isRomanUrdu(cleaned)) return cleaned;

    final StringBuffer out = StringBuffer();
    final RegExp token = RegExp(r"[A-Za-zÀ-ɏ']+|[^A-Za-zÀ-ɏ']+");
    for (final RegExpMatch match in token.allMatches(cleaned)) {
      final String piece = match[0]!;
      if (RegExp(r"^[A-Za-zÀ-ɏ']+$").hasMatch(piece)) {
        out.write(transliterateWord(piece));
      } else {
        out.write(piece);
      }
    }
    return out.toString();
  }

  /// Transliterates a single Roman Urdu word into Urdu script.
  ///
  /// Exposed for tests: the lexicon path and the rule path are asserted
  /// separately.
  static String transliterateWord(String word) {
    final String lower = word.toLowerCase();
    final String? known = _romanUrduLexicon[lower];
    if (known != null) return known;

    final StringBuffer out = StringBuffer();
    int i = 0;
    while (i < lower.length) {
      final String three = i + 3 <= lower.length ? lower.substring(i, i + 3) : '';
      final String two = i + 2 <= lower.length ? lower.substring(i, i + 2) : '';
      final String one = lower[i];
      if (three.isNotEmpty && _trigraphs.containsKey(three)) {
        out.write(_trigraphs[three]);
        i += 3;
      } else if (two.isNotEmpty && _digraphs.containsKey(two)) {
        out.write(_digraphs[two]);
        i += 2;
      } else {
        out.write(_monographs[one] ?? '');
        i += 1;
      }
    }
    final String result = out.toString();
    return result.isEmpty ? word : result;
  }

  /// Splits [text] into runs that each read in one direction.
  ///
  /// Direction is decided **per run**, not per screen: a caption containing both
  /// scripts renders each part correctly (design.md §6.2). Neutral characters
  /// (spaces, digits, punctuation) attach to the run before them, so
  /// "Meeting at 3 بجے" keeps its digit with the English.
  static List<TextRun> splitRuns(String text) {
    final String cleaned = stripDevanagari(text);
    if (cleaned.isEmpty) return const <TextRun>[];

    final List<TextRun> runs = <TextRun>[];
    final StringBuffer buffer = StringBuffer();
    ReadingDirection? current;

    void flush() {
      if (buffer.isEmpty) return;
      runs.add(TextRun(buffer.toString(), current ?? ReadingDirection.leftToRight));
      buffer.clear();
    }

    for (final int rune in cleaned.runes) {
      final ReadingDirection? direction = _isArabic(rune)
          ? ReadingDirection.rightToLeft
          : _isLatinLetter(rune)
          ? ReadingDirection.leftToRight
          : null;

      if (direction == null) {
        // Neutral: stay in the current run.
        buffer.writeCharCode(rune);
        continue;
      }
      if (current != null && direction != current) {
        flush();
      }
      current = direction;
      buffer.writeCharCode(rune);
    }
    flush();
    return List<TextRun>.unmodifiable(runs);
  }

  /// The dominant direction of [text], for a whole-field decision such as which
  /// way the composer should type.
  static ReadingDirection dominantDirection(String text) {
    int rtl = 0;
    int ltr = 0;
    for (final int rune in stripDevanagari(text).runes) {
      if (_isArabic(rune)) {
        rtl++;
      } else if (_isLatinLetter(rune)) {
        ltr++;
      }
    }
    return rtl > ltr ? ReadingDirection.rightToLeft : ReadingDirection.leftToRight;
  }
}

/// Words that signal Urdu when written in Latin letters. Chosen to avoid common
/// English words wherever possible; the classifier requires a share of them,
/// not one hit.
const Set<String> _romanUrduMarkers = <String>{
  'aap', 'aapka', 'aapko', 'acha', 'accha', 'agar', 'ajj', 'allah', 'ammi',
  'abbu', 'aur', 'bahut', 'bohot', 'bhai', 'behen', 'bhi', 'bola', 'bolo',
  'chahiye', 'chalo', 'dost', 'ghar', 'haan', 'hai', 'hain', 'ho', 'hoon',
  'hun', 'insha', 'ji', 'kaam', 'kahan', 'kaise', 'kaisa', 'kaisi', 'karo',
  'karna', 'kya', 'kyun', 'kyunki', 'lekin', 'main', 'mein', 'mera', 'meri',
  'mujhe', 'nahi', 'nahin', 'pani', 'phir', 'raha', 'rahi', 'sahi', 'shukriya',
  'subah', 'theek', 'thik', 'tum', 'tumhara', 'waqt', 'wapas', 'ye', 'yeh',
  'zara', 'zaroor', 'khana', 'baat', 'batao', 'samajh', 'suno', 'dekho',
  'milna', 'jana', 'aana', 'kal', 'aaj', 'raat', 'sham', 'din',
};

/// Roman Urdu words with a settled spelling in Urdu script. The rule-based
/// transliterator handles everything else.
const Map<String, String> _romanUrduLexicon = <String, String>{
  'aap': 'آپ',
  'aapka': 'آپ کا',
  'aapko': 'آپ کو',
  'acha': 'اچھا',
  'accha': 'اچھا',
  'aaj': 'آج',
  'agar': 'اگر',
  'ammi': 'امی',
  'abbu': 'ابو',
  'aur': 'اور',
  'bahut': 'بہت',
  'bohot': 'بہت',
  'baat': 'بات',
  'batao': 'بتاؤ',
  'bhai': 'بھائی',
  'behen': 'بہن',
  'bhi': 'بھی',
  'chahiye': 'چاہیے',
  'chalo': 'چلو',
  'dekho': 'دیکھو',
  'din': 'دن',
  'dost': 'دوست',
  'ghar': 'گھر',
  'haan': 'ہاں',
  'hai': 'ہے',
  'hain': 'ہیں',
  'ho': 'ہو',
  'hoon': 'ہوں',
  'hun': 'ہوں',
  'ji': 'جی',
  'kaam': 'کام',
  'kahan': 'کہاں',
  'kaise': 'کیسے',
  'kaisa': 'کیسا',
  'kaisi': 'کیسی',
  'kal': 'کل',
  'karo': 'کرو',
  'karna': 'کرنا',
  'khana': 'کھانا',
  'kya': 'کیا',
  'kyun': 'کیوں',
  'kyunki': 'کیونکہ',
  'lekin': 'لیکن',
  'main': 'میں',
  'mein': 'میں',
  'mera': 'میرا',
  'meri': 'میری',
  'mujhe': 'مجھے',
  'nahi': 'نہیں',
  'nahin': 'نہیں',
  'pani': 'پانی',
  'phir': 'پھر',
  'raat': 'رات',
  'raha': 'رہا',
  'rahi': 'رہی',
  'sahi': 'صحیح',
  'sham': 'شام',
  'shukriya': 'شکریہ',
  'subah': 'صبح',
  'suno': 'سنو',
  'theek': 'ٹھیک',
  'thik': 'ٹھیک',
  'tum': 'تم',
  'tumhara': 'تمہارا',
  'waqt': 'وقت',
  'wapas': 'واپس',
  'ye': 'یہ',
  'yeh': 'یہ',
  'zara': 'ذرا',
  'zaroor': 'ضرور',
};

const Map<String, String> _trigraphs = <String, String>{
  'chh': 'چھ',
  'shh': 'ش',
  'aae': 'آئی',
};

const Map<String, String> _digraphs = <String, String>{
  'kh': 'کھ',
  'gh': 'گھ',
  'ch': 'چ',
  'sh': 'ش',
  'th': 'تھ',
  'ph': 'پھ',
  'bh': 'بھ',
  'dh': 'دھ',
  'jh': 'جھ',
  'rh': 'ڑھ',
  'zh': 'ژ',
  'aa': 'ا',
  'ee': 'ی',
  'ii': 'ی',
  'oo': 'و',
  'uu': 'و',
  'ai': 'ای',
  'au': 'او',
  'ou': 'او',
  'ay': 'ے',
  'ny': 'نی',
  'qu': 'ق',
};

const Map<String, String> _monographs = <String, String>{
  'a': 'ا',
  'b': 'ب',
  'c': 'ک',
  'd': 'د',
  'e': 'ے',
  'f': 'ف',
  'g': 'گ',
  'h': 'ہ',
  'i': 'ی',
  'j': 'ج',
  'k': 'ک',
  'l': 'ل',
  'm': 'م',
  'n': 'ن',
  'o': 'و',
  'p': 'پ',
  'q': 'ق',
  'r': 'ر',
  's': 'س',
  't': 'ت',
  'u': 'و',
  'v': 'و',
  'w': 'و',
  'x': 'کس',
  'y': 'ی',
  'z': 'ز',
  "'": '',
};
