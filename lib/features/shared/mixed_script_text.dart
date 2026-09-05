import 'package:flutter/material.dart';
import 'package:humsukhan/core/theme/app_tokens.dart';
import 'package:humsukhan/domain/speech/language_policy.dart';

/// Renders text whose script may change mid-sentence.
///
/// Direction is decided **per run**, not per screen: "Meeting at 3 بجے" reads
/// correctly because each run carries its own direction and font
/// (design.md §6.2). Devanagari is stripped before anything is drawn.
class MixedScriptText extends StatelessWidget {
  /// Creates mixed-script text.
  const MixedScriptText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.scale = 1.0,
  });

  /// What to render.
  final String text;

  /// The base style; the family and height are set per run.
  final TextStyle? style;

  /// How the whole paragraph aligns.
  final TextAlign? textAlign;

  /// A multiplier applied on top of the style's size, for the caption-size
  /// setting.
  final double scale;

  @override
  Widget build(BuildContext context) {
    final TextStyle base =
        style ?? Theme.of(context).textTheme.bodyLarge ?? const TextStyle();
    final List<TextRun> runs = LanguagePolicy.splitRuns(text);

    if (runs.isEmpty) {
      return Text('', style: base, textAlign: textAlign);
    }

    final ReadingDirection paragraph = LanguagePolicy.dominantDirection(text);

    return Directionality(
      textDirection: paragraph == ReadingDirection.rightToLeft
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: Text.rich(
        TextSpan(
          children: runs
              .map(
                (TextRun run) => TextSpan(
                  text: run.text,
                  style: styleForRun(base, run, scale),
                ),
              )
              .toList(growable: false),
        ),
        textAlign: textAlign,
      ),
    );
  }

  /// The style a single [run] is drawn with.
  ///
  /// Exposed for the widget test that asserts Urdu runs carry Nastaliq metrics.
  static TextStyle styleForRun(TextStyle base, TextRun run, double scale) {
    final bool rtl = run.direction == ReadingDirection.rightToLeft;
    return base.copyWith(
      fontFamily: rtl ? AppTokens.urduFontFamily : AppTokens.latinFontFamily,
      // Nastaliq descenders clip without this. Applied to every Urdu run.
      height: rtl ? AppTokens.urduLineHeight : base.height,
      fontSize: (base.fontSize ?? AppTokens.body) * scale,
    );
  }
}
