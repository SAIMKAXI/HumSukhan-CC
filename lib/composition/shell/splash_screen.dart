import 'package:flutter/material.dart';
import 'package:humsukhan/core/theme/app_tokens.dart';
import 'package:humsukhan/features/shared/brand_logo.dart';

/// The first frame: the brand mark and what the app is waiting for.
///
/// The message is exposed to screen readers and is never a bare spinner.
class SplashScreen extends StatelessWidget {
  /// Creates a splash screen.
  const SplashScreen({required this.message, super.key});

  /// What is happening.
  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Semantics(
          liveRegion: true,
          label: message,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const BrandLogo(size: 112),
              const SizedBox(height: AppTokens.spaceLg),
              Text('HumSukhan', style: theme.textTheme.headlineMedium),
              const SizedBox(height: AppTokens.spaceXs),
              Text(
                'ہم سخن',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontFamily: AppTokens.urduFontFamily,
                  height: AppTokens.urduLineHeight,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppTokens.spaceXl),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(height: AppTokens.spaceMd),
              Text(message, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
