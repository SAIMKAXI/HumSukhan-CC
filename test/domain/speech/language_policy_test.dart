import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/domain/speech/language_policy.dart';

void main() {
  group('classify', () {
    test('plain English is English', () {
      expect(
        LanguagePolicy.classify('Where is the meeting room?'),
        CaptionLanguage.english,
      );
    });

    test('Urdu script is Urdu', () {
      expect(LanguagePolicy.classify('میٹنگ کہاں ہے؟'), CaptionLanguage.urdu);
    });

    test('Roman Urdu is reported as Roman Urdu, not English', () {
      expect(
        LanguagePolicy.classify('aap kaise hain bhai'),
        CaptionLanguage.romanUrdu,
      );
    });

    test('both scripts in one sentence is mixed', () {
      expect(
        LanguagePolicy.classify('The meeting is at 3, ٹھیک ہے؟'),
        CaptionLanguage.mixed,
      );
    });

    test('empty text is undetermined, never a guess', () {
      expect(LanguagePolicy.classify('   '), CaptionLanguage.undetermined);
    });

    test('a single English word containing a marker stays English', () {
      // "main" is a marker word but also ordinary English.
      expect(
        LanguagePolicy.classify('the main entrance is closed today'),
        CaptionLanguage.english,
      );
    });
  });

  group('Devanagari', () {
    test('is never classified as Urdu', () {
      expect(
        LanguagePolicy.classify('मीटिंग कहाँ है'),
        CaptionLanguage.undetermined,
      );
    });

    test('is stripped before display', () {
      expect(
        LanguagePolicy.stripDevanagari('Meeting मीटिंग room'),
        'Meeting room',
      );
    });

    test('stripping leaves non-Devanagari text untouched', () {
      const String text = 'میٹنگ room 3';
      expect(LanguagePolicy.stripDevanagari(text), text);
    });

    test('mixed Devanagari and Urdu keeps only the Urdu', () {
      expect(LanguagePolicy.stripDevanagari('ہم मीटिंग سخن'), 'ہم سخن');
    });

    test('splitRuns never emits a Devanagari run', () {
      final List<TextRun> runs = LanguagePolicy.splitRuns('hello मीटिंग ہیلو');
      expect(
        runs.any((TextRun r) => LanguagePolicy.hasDevanagari(r.text)),
        isFalse,
      );
    });
  });

  group('Roman Urdu normalisation', () {
    test('known words become Urdu script', () {
      expect(
        LanguagePolicy.normaliseRomanUrduToScript('aap kaise hain'),
        'آپ کیسے ہیں',
      );
    });

    test('unknown words are transliterated rather than dropped', () {
      final String out = LanguagePolicy.normaliseRomanUrduToScript(
        'mujhe darwaza kholna hai',
      );
      expect(LanguagePolicy.hasLatinScript(out), isFalse);
      expect(out, contains('مجھے'));
    });

    test('punctuation and spacing survive', () {
      expect(
        LanguagePolicy.normaliseRomanUrduToScript('aap theek hain?'),
        endsWith('?'),
      );
    });

    test('English is left alone — normalisation never guesses', () {
      const String english = 'Please close the door.';
      expect(LanguagePolicy.normaliseRomanUrduToScript(english), english);
    });
  });

  group('run splitting', () {
    test('a mixed caption splits per run, not per screen', () {
      final List<TextRun> runs = LanguagePolicy.splitRuns('Room 3 ہے');
      expect(runs.length, 2);
      expect(runs.first.direction, ReadingDirection.leftToRight);
      expect(runs.last.direction, ReadingDirection.rightToLeft);
    });

    test('neutral characters stay with the run before them', () {
      final List<TextRun> runs = LanguagePolicy.splitRuns('Room 3, ہے');
      expect(runs.first.text, 'Room 3, ');
    });

    test('a single-script caption is one run', () {
      expect(LanguagePolicy.splitRuns('hello there').length, 1);
    });

    test('empty text produces no runs', () {
      expect(LanguagePolicy.splitRuns(''), isEmpty);
    });

    test('runs concatenate back to the cleaned input', () {
      const String input = 'Meeting at 3 بجے شروع';
      final String rebuilt = LanguagePolicy.splitRuns(input)
          .map((TextRun r) => r.text)
          .join();
      expect(rebuilt, input);
    });
  });

  group('dominant direction', () {
    test('mostly Urdu reads right to left', () {
      expect(
        LanguagePolicy.dominantDirection('السلام علیکم hello'),
        ReadingDirection.rightToLeft,
      );
    });

    test('mostly English reads left to right', () {
      expect(
        LanguagePolicy.dominantDirection('hello everyone ہے'),
        ReadingDirection.leftToRight,
      );
    });
  });
}
