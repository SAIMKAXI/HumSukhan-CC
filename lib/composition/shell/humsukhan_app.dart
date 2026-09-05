import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:humsukhan/application/account/auth_controller.dart';
import 'package:humsukhan/application/common/operation_state.dart';
import 'package:humsukhan/application/providers.dart';
import 'package:humsukhan/core/l10n/app_language.dart';
import 'package:humsukhan/core/l10n/app_strings.dart';
import 'package:humsukhan/core/theme/app_theme.dart';
import 'package:humsukhan/domain/settings/app_settings.dart';
import 'package:humsukhan/composition/shell/account_gate.dart';

/// The application root.
///
/// Owns theme, locale and text scaling; everything below it is a screen.
class HumSukhanApp extends ConsumerWidget {
  /// Creates the app.
  const HumSukhanApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings settings = ref.watch(settingsProvider);
    final AppLanguage language = settings.appLanguage;
    final AppStrings strings = ref.watch(stringsProvider);

    return MaterialApp(
      title: strings(StringKey.appName),
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(ref.watch(themeVariantProvider), language),
      locale: language.locale,
      supportedLocales: AppLanguage.values
          .map((AppLanguage l) => l.locale)
          .toList(growable: false),
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (BuildContext context, Widget? child) {
        final MediaQueryData media = MediaQuery.of(context);
        return MediaQuery(
          // The in-app setting multiplies the platform scale; it never replaces
          // it (design.md §7).
          data: media.copyWith(
            textScaler: media.textScaler.clamp(
              minScaleFactor: 0.8,
              maxScaleFactor: 2.0,
            ),
          ),
          child: Directionality(
            textDirection: language.direction,
            child: _ScaledText(
              multiplier: settings.textScaleMultiplier,
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        );
      },
      home: const AccountGate(),
    );
  }
}

class _ScaledText extends StatelessWidget {
  const _ScaledText({required this.multiplier, required this.child});

  final double multiplier;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(
        textScaler: _MultipliedScaler(media.textScaler, multiplier),
      ),
      child: child,
    );
  }
}

/// Multiplies whatever the platform reports, rather than overriding it.
class _MultipliedScaler extends TextScaler {
  const _MultipliedScaler(this._base, this._multiplier);

  final TextScaler _base;
  final double _multiplier;

  @override
  double scale(double fontSize) => _base.scale(fontSize) * _multiplier;

  @override
  // The base class still declares this; TextScaler.scale is the live path.
  // ignore: deprecated_member_use
  double get textScaleFactor => _base.textScaleFactor * _multiplier;

  @override
  TextScaler clamp({double minScaleFactor = 0, double maxScaleFactor = 0}) =>
      _base.clamp(
        minScaleFactor: minScaleFactor,
        maxScaleFactor: maxScaleFactor,
      );
}

/// Whether the app has finished the work every screen depends on.
///
/// Exposed so the gate can show a real loading state instead of a blank frame.
bool settingsAreLoaded(OperationState<AppSettings> state) =>
    state is OperationSuccess<AppSettings> ||
    state is OperationFailure<AppSettings>;

/// Whether the account phase is still being determined.
bool isRestoringSession(AuthState state) => state.phase == AuthPhase.restoring;
