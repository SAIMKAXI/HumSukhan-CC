import 'package:flutter/material.dart';
import 'package:humsukhan/core/theme/app_tokens.dart';

/// The brand badge: the mark, cream, on brand green.
///
/// The asset is the adaptive-icon *foreground* — transparent, with safe-zone
/// padding — so the badge supplies the green itself and scales the mark by
/// 108/72 to reproduce the launcher's framing. Pointing this at the foreground
/// while filling the container with `colorScheme.surface` is what once made the
/// in-app logo lose its brand green (B13).
class BrandLogo extends StatelessWidget {
  /// Creates a badge [size] logical pixels square.
  const BrandLogo({super.key, this.size = 72, this.rounded = true});

  /// The badge's side length.
  final double size;

  /// Whether the corners are rounded.
  final bool rounded;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'HumSukhan',
    image: true,
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        // Must match the launcher icon's background exactly.
        color: AppTokens.brandIconBackground,
        borderRadius: rounded
            ? BorderRadius.circular(size * 0.22)
            : BorderRadius.zero,
      ),
      clipBehavior: Clip.antiAlias,
      child: Center(
        child: Image.asset(
          'assets/images/icon_mark.png',
          width: size * AppTokens.adaptiveIconScale,
          height: size * AppTokens.adaptiveIconScale,
        ),
      ),
    ),
  );
}
