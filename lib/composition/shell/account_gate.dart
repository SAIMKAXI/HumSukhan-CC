import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:humsukhan/application/account/auth_controller.dart';
import 'package:humsukhan/application/common/operation_state.dart';
import 'package:humsukhan/application/providers.dart';
import 'package:humsukhan/core/l10n/app_strings.dart';
import 'package:humsukhan/domain/account/account.dart';
import 'package:humsukhan/domain/settings/app_settings.dart';
import 'package:humsukhan/composition/shell/main_scaffold.dart';
import 'package:humsukhan/composition/shell/splash_screen.dart';
import 'package:humsukhan/features/auth/auth_screen.dart';
import 'package:humsukhan/features/onboarding/onboarding_screen.dart';

/// Decides which of the top-level surfaces the user sees.
///
/// The order is fixed: password recovery → settings loaded → signed in →
/// onboarding complete → the app. Each step is a real state, so the user never
/// meets a blank frame that might be any of them.
class AccountGate extends ConsumerStatefulWidget {
  /// Creates the gate.
  const AccountGate({super.key});

  @override
  ConsumerState<AccountGate> createState() => _AccountGateState();
}

class _AccountGateState extends ConsumerState<AccountGate> {
  String? _sweptFor;

  /// Sweeps expired material once per signed-in account.
  ///
  /// Runs here rather than in `main` because the stores are scoped to the user:
  /// before sign-in there is nothing of theirs to sweep.
  void _sweepFor(String userId) {
    if (_sweptFor == userId) return;
    _sweptFor = userId;
    unawaited(
      ref
          .read(retentionSweeperProvider)
          .sweep(
            conversationRetention: ref
                .read(settingsProvider)
                .retention
                .duration,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AuthState auth = ref.watch(authControllerProvider);
    final OperationState<AppSettings> settings = ref.watch(
      settingsControllerProvider,
    );
    final AppStrings strings = ref.watch(stringsProvider);

    // A recovery link takes precedence over everything, including a stale
    // session: the user followed it to set a password.
    if (auth.phase == AuthPhase.passwordRecovery) {
      return const AuthScreen(initialMode: AuthMode.passwordRecovery);
    }

    if (auth.phase == AuthPhase.restoring ||
        settings is OperationLoading<AppSettings>) {
      return SplashScreen(message: strings(StringKey.loading));
    }

    if (auth.phase != AuthPhase.signedIn) {
      return const AuthScreen();
    }

    final Account? account = auth.account;
    if (account != null) _sweepFor(account.id);

    if (!(settings.valueOrNull ?? const AppSettings()).onboardingComplete) {
      return const OnboardingScreen();
    }

    return const MainScaffold();
  }
}
