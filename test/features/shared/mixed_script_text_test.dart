import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/core/theme/app_tokens.dart';
import 'package:humsukhan/domain/speech/language_policy.dart';
import 'package:humsukhan/features/shared/mixed_script_text.dart';

void main() {
  group('per-run styling', () {
    test('an Urdu run gets Nastaliq with its extra line height', () {
      const TextRun run = TextRun('ہے', ReadingDirection.rightToLeft);

      final TextStyle style = MixedScriptText.styleForRun(
        const TextStyle(fontSize: 15),
        run,
        1,
      );

      expect(style.fontFamily, AppTokens.urduFontFamily);
      expect(
        style.height,
        AppTokens.urduLineHeight,
        reason: 'Nastaliq descenders clip without it',
      );
    });

    test('a Latin run gets the Latin family', () {
      const TextRun run = TextRun('hello', ReadingDirection.leftToRight);

      final TextStyle style = MixedScriptText.styleForRun(
        const TextStyle(fontSize: 15),
        run,
        1,
      );

      expect(style.fontFamily, AppTokens.latinFontFamily);
    });

    test('the caption scale multiplies the style size', () {
      const TextRun run = TextRun('hello', ReadingDirection.leftToRight);

      final TextStyle style = MixedScriptText.styleForRun(
        const TextStyle(fontSize: 15),
        run,
        1.5,
      );

      expect(style.fontSize, 22.5);
    });
  });

  group('rendering', () {
    /// Every span in the tree that actually carries characters.
    List<TextSpan> leafSpans(WidgetTester tester) {
      final RichText text = tester.widget<RichText>(find.byType(RichText));
      final List<TextSpan> leaves = <TextSpan>[];
      void visit(InlineSpan span) {
        if (span is! TextSpan) return;
        if (span.text != null && span.text!.isNotEmpty) leaves.add(span);
        for (final InlineSpan child in span.children ?? const <InlineSpan>[]) {
          visit(child);
        }
      }

      visit(text.text);
      return leaves;
    }

    testWidgets('a mixed caption renders one run per script', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: MixedScriptText('Room 3 ہے'))),
      );

      final List<TextSpan> runs = leafSpans(tester);
      expect(runs, hasLength(2));
      expect(runs.first.text, 'Room 3 ');
      expect(runs.first.style?.fontFamily, AppTokens.latinFontFamily);
      expect(runs.last.text, 'ہے');
      expect(runs.last.style?.fontFamily, AppTokens.urduFontFamily);
      expect(
        runs.last.style?.height,
        AppTokens.urduLineHeight,
        reason: 'every Urdu run carries Nastaliq leading',
      );
    });

    testWidgets('Devanagari never reaches the screen', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: MixedScriptText('hello मीटिंग there')),
        ),
      );

      final RichText text = tester.widget<RichText>(find.byType(RichText));
      final String rendered = (text.text as TextSpan).toPlainText();
      expect(LanguagePolicy.hasDevanagari(rendered), isFalse);
      expect(rendered, 'hello there');
    });

    testWidgets('empty text renders without throwing', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: MixedScriptText(''))),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a mostly-Urdu caption lays out right to left', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: MixedScriptText('السلام علیکم hi')),
        ),
      );

      final Directionality directionality = tester.widget<Directionality>(
        find
            .descendant(
              of: find.byType(MixedScriptText),
              matching: find.byType(Directionality),
            )
            .first,
      );
      expect(directionality.textDirection, TextDirection.rtl);
    });
  });
}
