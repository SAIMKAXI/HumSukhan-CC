import 'package:flutter/painting.dart';

/// The design system's constants: colour, spacing, radius, type scale.
///
/// Nothing in the app hardcodes a colour or a magic number — including the
/// launcher icon background, which must match [AppTokens.brandIconBackground]
/// exactly or the in-app badge visibly disagrees with the home screen.
abstract final class AppTokens {
  // ---- Brand ------------------------------------------------------------

  /// Launcher-icon background and the in-app brand badge fill.
  static const Color brandIconBackground = Color(0xFF53695B);

  // ---- Sage / forest palette -------------------------------------------

  /// Primary, and the success accent.
  static const Color deepSage = Color(0xFF506858);

  /// Primary variant, and the informational accent.
  static const Color primarySage = Color(0xFF587060);

  /// Secondary surface.
  static const Color mediumSage = Color(0xFF607868);

  /// Secondary surface, lighter.
  static const Color lightSage = Color(0xFF688070);

  /// Muted text on light surfaces.
  static const Color softSage = Color(0xFF789080);

  /// Dark-mode elevated surface.
  static const Color darkForest = Color(0xFF3A4F42);

  /// Dark-mode surface.
  static const Color deepForest = Color(0xFF2D3E34);

  /// Dark-mode background, and primary text on light surfaces.
  static const Color forestBlack = Color(0xFF1E2B22);

  /// Light background.
  static const Color warmIvory = Color(0xFFF8F0E8);

  /// Light surface.
  static const Color creamWhite = Color(0xFFF0E8E0);

  /// Light surface variant.
  static const Color softCream = Color(0xFFF0F0E0);

  /// Divider and outline.
  static const Color borderSage = Color(0xFFD0D8D4);

  /// Muted foreground.
  static const Color mutedSageGray = Color(0xFFB8C4BC);

  /// Disabled foreground and fill.
  static const Color disabledSage = Color(0xFFC8D0CC);

  /// Non-critical alerts.
  static const Color warning = Color(0xFFB8943C);

  /// Errors, critical alerts, and the active-recording state.
  static const Color error = Color(0xFFB85450);

  // ---- Spacing ----------------------------------------------------------

  /// 4dp.
  static const double spaceXs = 4;

  /// 8dp.
  static const double spaceSm = 8;

  /// 16dp.
  static const double spaceMd = 16;

  /// 24dp.
  static const double spaceLg = 24;

  /// 32dp.
  static const double spaceXl = 32;

  /// 48dp.
  static const double spaceXxl = 48;

  // ---- Radius -----------------------------------------------------------

  /// 12dp.
  static const double radiusSm = 12;

  /// 16dp.
  static const double radiusMd = 16;

  /// 20dp.
  static const double radiusLg = 20;

  /// Fully rounded.
  static const double radiusFull = 999;

  // ---- Type scale -------------------------------------------------------

  /// 12sp.
  static const double captionSmall = 12;

  /// 13sp.
  static const double caption = 13;

  /// 15sp.
  static const double body = 15;

  /// 17sp.
  static const double bodyLarge = 17;

  /// 20sp.
  static const double title = 20;

  /// 28sp.
  static const double headline = 28;

  /// 32sp.
  static const double display = 32;

  // ---- Hit targets ------------------------------------------------------

  /// The smallest tappable square anywhere in the app.
  static const double minHitTarget = 40;

  /// The primary microphone control.
  static const double primaryMicSize = 78;

  // ---- Fonts ------------------------------------------------------------

  /// Latin family.
  static const String latinFontFamily = 'NotoSans';

  /// Urdu / Arabic family.
  static const String urduFontFamily = 'NotoNastaliqUrdu';

  /// Nastaliq descenders clip at normal line height. This multiplier is applied
  /// to *every* Urdu text style — it is not optional polish.
  static const double urduLineHeight = 1.65;

  /// The in-app badge reverses the adaptive-icon safe zone so the mark is framed
  /// exactly as the launcher frames it.
  static const double adaptiveIconScale = 108 / 72;
}
