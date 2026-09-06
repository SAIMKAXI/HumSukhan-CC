import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/application/providers.dart';
import 'package:humsukhan/core/l10n/app_language.dart';
import 'package:humsukhan/core/l10n/app_strings.dart';
import 'package:humsukhan/core/theme/app_theme.dart';
import 'package:humsukhan/domain/settings/app_settings.dart';
import 'package:humsukhan/features/settings/settings_screen.dart';

import '../../fakes/fake_app_ports.dart';
import '../../support/harness.dart';

void main() {
  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(SettingsScreen)));

  group('appearance', () {
    testWidgets('high contrast is its own theme, not a filter', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(harness(child: const SettingsScreen()));
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(SwitchListTile, english(StringKey.setHighContrast)),
      );
      await tester.pumpAndSettle();

      final ProviderContainer container = containerOf(tester);
      expect(
        container.read(themeVariantProvider),
        AppThemeVariant.highContrast,
      );
    });

    testWidgets('high contrast takes precedence over dark mode', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(
          child: const SettingsScreen(),
          settingsPort: FakeSettingsPort(
            initial: const AppSettings(darkMode: true, highContrast: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        containerOf(tester).read(themeVariantProvider),
        AppThemeVariant.highContrast,
      );
    });

    testWidgets('dark mode is disabled while high contrast is on', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(
          child: const SettingsScreen(),
          settingsPort: FakeSettingsPort(
            initial: const AppSettings(highContrast: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final SwitchListTile dark = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, english(StringKey.setDarkMode)),
      );
      expect(
        dark.onChanged,
        isNull,
        reason: 'a control that cannot take effect is disabled',
      );
    });

    testWidgets('large text multiplies rather than replaces', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(harness(child: const SettingsScreen()));
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(SwitchListTile, english(StringKey.setLargeText)),
      );
      await tester.pumpAndSettle();

      expect(
        containerOf(tester).read(settingsProvider).textScaleMultiplier,
        1.2,
      );
    });

    testWidgets('the caption preview reflects the caption size', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(harness(child: const SettingsScreen()));
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          english(StringKey.setCaptionPreview),
          findRichText: true,
        ),
        findsOneWidget,
      );
    });
  });

  group('language', () {
    testWidgets('switching to Urdu changes the interface language', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(harness(child: const SettingsScreen()));
      await tester.pumpAndSettle();

      await tester.tap(
        find
            .descendant(
              of: find.byType(SegmentedButton<AppLanguage>),
              matching: find.text(english(StringKey.setLanguageUrdu)),
            )
            .first,
      );
      await tester.pumpAndSettle();

      expect(containerOf(tester).read(appLanguageProvider), AppLanguage.urdu);
      expect(
        containerOf(tester).read(stringsProvider).language,
        AppLanguage.urdu,
      );
    });
  });

  group('alerts', () {
    testWidgets('turning every channel off is called out', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(
          child: const SettingsScreen(),
          settingsPort: FakeSettingsPort(
            initial: const AppSettings(
              alertChannels: AlertChannels(
                haptic: false,
                visual: false,
                screenFlash: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // A user with no channel on cannot be alerted at all; the screen says so
      // rather than letting it happen quietly.
      await tester.scrollUntilVisible(
        find.text(english(StringKey.setNoAlertChannels)),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(english(StringKey.setNoAlertChannels)), findsOneWidget);
    });
  });

  group('retention', () {
    testWidgets('only the supported windows are offered', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(harness(child: const SettingsScreen()));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.textContaining('15 days'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('15 days'), findsOneWidget);
      expect(find.textContaining('30 days'), findsNothing);
    });
  });

  group('the version is shown', () {
    testWidgets('and matches the shipped version', (WidgetTester tester) async {
      await tester.pumpWidget(harness(child: const SettingsScreen()));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.textContaining('Version'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('Version 1.0.0'), findsOneWidget);
    });
  });
}
