import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/core/l10n/app_language.dart';
import 'package:humsukhan/core/l10n/app_strings.dart';
import 'package:humsukhan/core/theme/app_theme.dart';
import 'package:humsukhan/core/theme/app_tokens.dart';
import 'package:humsukhan/domain/conversation/caption.dart';
import 'package:humsukhan/features/shared/caption_bubble.dart';
import 'package:humsukhan/features/shared/state_views.dart';

void main() {
  final AppStrings strings = AppStrings.of(AppLanguage.english);

  Widget wrap(Widget child) => MaterialApp(
    theme: AppTheme.build(AppThemeVariant.light, AppLanguage.english),
    home: Scaffold(body: child),
  );

  Caption caption(String id, String text, {CaptionSpeaker? speaker}) => Caption(
    id: id,
    text: text,
    speaker: speaker ?? CaptionSpeaker.other,
    createdAt: DateTime.utc(2026, 3, 4),
  );

  group('an empty state never stands in for a failure', () {
    testWidgets('an empty state shows its own copy and no error glyph', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const EmptyStateView(title: 'Nothing yet', message: 'Record one.'),
        ),
      );

      expect(find.text('Nothing yet'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsNothing);
    });

    testWidgets('an error state shows the reason and the remedy', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const ErrorStateView(
            title: 'That did not work',
            message: 'You are offline.',
            remedy: 'Reconnect and try again.',
          ),
        ),
      );

      expect(find.text('You are offline.'), findsOneWidget);
      expect(find.text('Reconnect and try again.'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('a retry appears only when retrying is meaningful', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const ErrorStateView(title: 'Failed', message: 'Nothing to be done.'),
        ),
      );
      expect(find.byType(FilledButton), findsNothing);

      await tester.pumpWidget(
        wrap(
          ErrorStateView(
            title: 'Failed',
            message: 'Try again.',
            onRetry: () {},
            retryLabel: 'Try again',
          ),
        ),
      );
      expect(find.byType(FilledButton), findsOneWidget);
    });

    testWidgets('a loading state always says what it is waiting for', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrap(const LoadingStateView(message: 'Generating the summary…')),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Generating the summary…'), findsOneWidget);
    });

    testWidgets('a cancellable spinner offers the way out', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrap(LoadingStateView(message: 'Working…', onCancel: () {})),
      );
      expect(find.text('Cancel'), findsOneWidget);
    });
  });

  group('the AI disclaimer travels with generated output', () {
    testWidgets('it renders the disclaimer copy', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(AiDisclaimer(strings: strings)));
      expect(find.text(strings(StringKey.aiDisclaimer)), findsOneWidget);
    });
  });

  group('caption bubbles', () {
    testWidgets('the speak button is disabled for an empty caption', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          SpeakableCaptionBubble(
            caption: caption('a', '   '),
            strings: strings,
            onSpeak: () {},
          ),
        ),
      );

      final IconButton button = tester.widget<IconButton>(
        find.byType(IconButton),
      );
      expect(
        button.onPressed,
        isNull,
        reason: 'a control that cannot work is disabled, not silently inert',
      );
    });

    testWidgets('the speak button meets the minimum hit target', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          SpeakableCaptionBubble(
            caption: caption('a', 'hello'),
            strings: strings,
            onSpeak: () {},
          ),
        ),
      );

      final IconButton button = tester.widget<IconButton>(
        find.byType(IconButton),
      );
      expect(
        button.constraints!.minWidth,
        greaterThanOrEqualTo(AppTokens.minHitTarget),
      );
      expect(
        button.constraints!.minHeight,
        greaterThanOrEqualTo(AppTokens.minHitTarget),
      );
    });

    testWidgets(
      'only the caption being spoken shows stop, even when the text matches',
      (WidgetTester tester) async {
        // Two captions with identical text: comparing text made both show the
        // stop icon (design.md §9). Identity is by id.
        await tester.pumpWidget(
          wrap(
            Column(
              children: <Widget>[
                SpeakableCaptionBubble(
                  caption: caption('first', 'yes'),
                  strings: strings,
                  isSpeaking: true,
                  onStopSpeaking: () {},
                ),
                SpeakableCaptionBubble(
                  caption: caption('second', 'yes'),
                  strings: strings,
                  onSpeak: () {},
                ),
              ],
            ),
          ),
        );

        expect(find.byIcon(Icons.stop), findsOneWidget);
        expect(find.byIcon(Icons.volume_up_outlined), findsOneWidget);
      },
    );

    testWidgets('an own caption is labelled as the user', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          SpeakableCaptionBubble(
            caption: caption('a', 'I am here', speaker: CaptionSpeaker.own),
            strings: strings,
            onSpeak: () {},
          ),
        ),
      );
      expect(find.text(strings(StringKey.everydayYouLabel)), findsOneWidget);
    });

    testWidgets('the detected language is shown, not silently corrected', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          SpeakableCaptionBubble(
            caption: caption('a', 'aap kaise hain'),
            strings: strings,
            onSpeak: () {},
          ),
        ),
      );
      expect(find.text(strings(StringKey.langRomanUrdu)), findsOneWidget);
    });

    testWidgets('a mixed caption never shows the internal name "Auto"', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          SpeakableCaptionBubble(
            caption: caption('a', 'Room 3 ہے'),
            strings: strings,
            onSpeak: () {},
          ),
        ),
      );

      expect(find.text('Auto'), findsNothing);
      expect(find.text(strings(StringKey.langMixed)), findsOneWidget);
    });

    testWidgets('a partial bubble renders in italics', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrap(PartialCaptionBubble(text: 'half a sen', strings: strings)),
      );
      expect(find.byType(PartialCaptionBubble), findsOneWidget);
    });
  });
}
