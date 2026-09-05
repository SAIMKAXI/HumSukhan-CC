import 'package:flutter/material.dart';
import 'package:humsukhan/core/l10n/app_language.dart';
import 'package:humsukhan/core/theme/app_tokens.dart';

/// Which of the three themes to build.
enum AppThemeVariant {
  /// Sage on ivory.
  light,

  /// Cream on forest.
  dark,

  /// Pure black and white with heavy borders. A dedicated theme, not a filter:
  /// a derived one cannot guarantee contrast ratios.
  highContrast,
}

/// Builds the app's [ThemeData].
abstract final class AppTheme {
  /// The theme for [variant], with type metrics correct for [language].
  static ThemeData build(AppThemeVariant variant, AppLanguage language) {
    final ColorScheme scheme = switch (variant) {
      AppThemeVariant.light => _lightScheme,
      AppThemeVariant.dark => _darkScheme,
      AppThemeVariant.highContrast => _highContrastScheme,
    };
    final bool contrast = variant == AppThemeVariant.highContrast;
    final TextTheme text = _textTheme(scheme, language);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      fontFamily: fontFamilyFor(language),
      textTheme: text,
      visualDensity: VisualDensity.standard,
      dividerTheme: DividerThemeData(
        color: scheme.outline,
        thickness: contrast ? 2 : 1,
        space: AppTokens.spaceMd,
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerHighest,
        elevation: contrast ? 0 : 1,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          side: BorderSide(color: scheme.outline, width: contrast ? 2 : 1),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: contrast ? 0 : 2,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerHighest,
        indicatorColor: scheme.primaryContainer,
        elevation: 0,
        labelTextStyle: WidgetStatePropertyAll<TextStyle>(
          text.labelMedium ?? const TextStyle(),
        ),
        // Labels are always visible: an icon alone is not a caption.
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(
            AppTokens.minHitTarget * 2,
            AppTokens.minHitTarget + 8,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.spaceLg,
            vertical: AppTokens.spaceSm + 4,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusSm),
            side: contrast
                ? BorderSide(color: scheme.onPrimary, width: 2)
                : BorderSide.none,
          ),
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(
            AppTokens.minHitTarget * 2,
            AppTokens.minHitTarget + 8,
          ),
          side: BorderSide(color: scheme.outline, width: contrast ? 2.5 : 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          ),
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(
            AppTokens.minHitTarget,
            AppTokens.minHitTarget,
          ),
          textStyle: text.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(
            AppTokens.minHitTarget,
            AppTokens.minHitTarget,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHighest,
        side: BorderSide(color: scheme.outline, width: contrast ? 2 : 1),
        labelStyle: text.labelMedium,
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.spaceSm + 4,
          vertical: AppTokens.spaceSm,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusFull),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTokens.spaceMd,
          vertical: AppTokens.spaceSm + 4,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          borderSide: BorderSide(
            color: scheme.outline,
            width: contrast ? 2 : 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          borderSide: BorderSide(
            color: scheme.outline,
            width: contrast ? 2 : 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          borderSide: BorderSide(
            color: scheme.primary,
            width: contrast ? 2.5 : 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          borderSide: BorderSide(
            color: scheme.error,
            width: contrast ? 2.5 : 2,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        ),
      ),
      listTileTheme: ListTileThemeData(
        minVerticalPadding: AppTokens.spaceSm + 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: contrast
            ? WidgetStateProperty.resolveWith<Color>(
                (Set<WidgetState> states) =>
                    states.contains(WidgetState.selected)
                    ? scheme.onPrimary
                    : scheme.onSurface,
              )
            : null,
      ),
    );
  }

  /// The family used for text written in [language].
  static String fontFamilyFor(AppLanguage language) => switch (language) {
    AppLanguage.english => AppTokens.latinFontFamily,
    AppLanguage.urdu => AppTokens.urduFontFamily,
  };

  static const ColorScheme _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppTokens.deepSage,
    onPrimary: AppTokens.warmIvory,
    primaryContainer: AppTokens.borderSage,
    onPrimaryContainer: AppTokens.forestBlack,
    secondary: AppTokens.mediumSage,
    onSecondary: AppTokens.warmIvory,
    secondaryContainer: AppTokens.softCream,
    onSecondaryContainer: AppTokens.darkForest,
    tertiary: AppTokens.primarySage,
    onTertiary: AppTokens.warmIvory,
    error: AppTokens.error,
    onError: AppTokens.warmIvory,
    errorContainer: Color(0xFFF2DAD9),
    onErrorContainer: Color(0xFF5C2321),
    surface: AppTokens.warmIvory,
    onSurface: AppTokens.forestBlack,
    surfaceContainerHighest: AppTokens.creamWhite,
    onSurfaceVariant: AppTokens.darkForest,
    outline: AppTokens.borderSage,
    outlineVariant: AppTokens.disabledSage,
    inverseSurface: AppTokens.forestBlack,
    onInverseSurface: AppTokens.warmIvory,
    inversePrimary: AppTokens.lightSage,
    shadow: Color(0x33000000),
    scrim: Color(0x99000000),
  );

  static const ColorScheme _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppTokens.lightSage,
    onPrimary: AppTokens.forestBlack,
    primaryContainer: AppTokens.darkForest,
    onPrimaryContainer: AppTokens.warmIvory,
    secondary: AppTokens.softSage,
    onSecondary: AppTokens.forestBlack,
    secondaryContainer: AppTokens.deepForest,
    onSecondaryContainer: AppTokens.creamWhite,
    tertiary: AppTokens.mutedSageGray,
    onTertiary: AppTokens.forestBlack,
    error: Color(0xFFE08B87),
    onError: AppTokens.forestBlack,
    errorContainer: Color(0xFF5C2321),
    onErrorContainer: Color(0xFFF2DAD9),
    surface: AppTokens.forestBlack,
    onSurface: AppTokens.creamWhite,
    surfaceContainerHighest: AppTokens.deepForest,
    onSurfaceVariant: AppTokens.mutedSageGray,
    outline: AppTokens.darkForest,
    outlineVariant: AppTokens.deepForest,
    inverseSurface: AppTokens.warmIvory,
    onInverseSurface: AppTokens.forestBlack,
    inversePrimary: AppTokens.deepSage,
    shadow: Color(0x66000000),
    scrim: Color(0xCC000000),
  );

  /// Pure black on pure white. Every pairing here is at least 7:1.
  static const ColorScheme _highContrastScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF000000),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFFFFFFF),
    onPrimaryContainer: Color(0xFF000000),
    secondary: Color(0xFF000000),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFFFFFFF),
    onSecondaryContainer: Color(0xFF000000),
    tertiary: Color(0xFF000000),
    onTertiary: Color(0xFFFFFFFF),
    error: Color(0xFF8C0000),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFFFFF),
    onErrorContainer: Color(0xFF8C0000),
    surface: Color(0xFFFFFFFF),
    onSurface: Color(0xFF000000),
    surfaceContainerHighest: Color(0xFFFFFFFF),
    onSurfaceVariant: Color(0xFF000000),
    outline: Color(0xFF000000),
    outlineVariant: Color(0xFF000000),
    inverseSurface: Color(0xFF000000),
    onInverseSurface: Color(0xFFFFFFFF),
    inversePrimary: Color(0xFFFFFFFF),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
  );

  static TextTheme _textTheme(ColorScheme scheme, AppLanguage language) {
    final String family = fontFamilyFor(language);
    // Nastaliq descenders clip at normal line height, so Urdu carries extra
    // leading on *every* style. This is a correctness fix, not polish.
    final double height = language == AppLanguage.urdu
        ? AppTokens.urduLineHeight
        : 1.35;

    TextStyle style(double size, FontWeight weight, Color colour) => TextStyle(
      fontFamily: family,
      fontSize: size,
      fontWeight: weight,
      height: height,
      color: colour,
    );

    return TextTheme(
      displayLarge: style(AppTokens.display, FontWeight.w700, scheme.onSurface),
      displayMedium: style(
        AppTokens.headline,
        FontWeight.w700,
        scheme.onSurface,
      ),
      headlineLarge: style(
        AppTokens.headline,
        FontWeight.w600,
        scheme.onSurface,
      ),
      headlineMedium: style(
        AppTokens.title + 4,
        FontWeight.w600,
        scheme.onSurface,
      ),
      titleLarge: style(AppTokens.title, FontWeight.w600, scheme.onSurface),
      titleMedium: style(
        AppTokens.bodyLarge,
        FontWeight.w600,
        scheme.onSurface,
      ),
      titleSmall: style(AppTokens.body, FontWeight.w600, scheme.onSurface),
      bodyLarge: style(AppTokens.bodyLarge, FontWeight.w400, scheme.onSurface),
      bodyMedium: style(AppTokens.body, FontWeight.w400, scheme.onSurface),
      bodySmall: style(
        AppTokens.caption,
        FontWeight.w400,
        scheme.onSurfaceVariant,
      ),
      labelLarge: style(AppTokens.body, FontWeight.w600, scheme.onSurface),
      labelMedium: style(AppTokens.caption, FontWeight.w500, scheme.onSurface),
      labelSmall: style(
        AppTokens.captionSmall,
        FontWeight.w500,
        scheme.onSurfaceVariant,
      ),
    );
  }
}
