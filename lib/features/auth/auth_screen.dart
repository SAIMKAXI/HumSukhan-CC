import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:humsukhan/application/account/auth_controller.dart';
import 'package:humsukhan/application/providers.dart';
import 'package:humsukhan/core/failure/failure.dart';
import 'package:humsukhan/core/l10n/app_strings.dart';
import 'package:humsukhan/core/theme/app_tokens.dart';
import 'package:humsukhan/features/shared/brand_logo.dart';

/// Which form the one auth screen is showing.
enum AuthMode {
  /// Sign in with an existing account.
  signIn,

  /// Create an account.
  signUp,

  /// Ask for a reset link.
  forgotPassword,

  /// Set a new password after following a reset link.
  passwordRecovery,
}

/// Sign in, sign up, reset and recovery, in one screen driven by a mode.
///
/// Errors are specific ("enter a valid email"), never "error", and every
/// outcome — including success — is stated on screen.
class AuthScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const AuthScreen({super.key, this.initialMode = AuthMode.signIn});

  /// Which form to show first.
  final AuthMode initialMode;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  late AuthMode _mode = widget.initialMode;
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _name = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  void _setMode(AuthMode mode) => setState(() => _mode = mode);

  Future<void> _submit() async {
    final AuthController controller = ref
        .read(authControllerProvider.notifier)
        .controller;
    switch (_mode) {
      case AuthMode.signIn:
        await controller.signIn(email: _email.text, password: _password.text);
      case AuthMode.signUp:
        await controller.signUp(
          email: _email.text,
          password: _password.text,
          displayName: _name.text.trim().isEmpty ? null : _name.text,
        );
      case AuthMode.forgotPassword:
        await controller.sendPasswordReset(_email.text);
      case AuthMode.passwordRecovery:
        await controller.updatePassword(_password.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = ref.watch(stringsProvider);
    final AuthState auth = ref.watch(authControllerProvider);
    final ThemeData theme = Theme.of(context);

    // Every failure and every success is announced, not just logged.
    ref.listen<AuthState>(authControllerProvider, (
      AuthState? previous,
      AuthState next,
    ) {
      final Failure? failure = next.failure;
      if (failure != null && failure != previous?.failure) {
        _announce(strings.describe(failure), isError: true);
        ref
            .read(authControllerProvider.notifier)
            .controller
            .acknowledgeFailure();
      }
      final AuthNotice? notice = next.notice;
      if (notice != null && notice != previous?.notice) {
        final StringKey key = switch (notice) {
          AuthNotice.resetLinkSent => StringKey.authResetSent,
          AuthNotice.passwordUpdated => StringKey.authPasswordUpdated,
          AuthNotice.signedIn => StringKey.authSignedIn,
        };
        _announce(strings(key));
        ref
            .read(authControllerProvider.notifier)
            .controller
            .acknowledgeNotice();
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTokens.spaceLg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Center(child: BrandLogo(size: 88)),
                  const SizedBox(height: AppTokens.spaceLg),
                  Text(
                    strings(_titleKey),
                    style: theme.textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppTokens.spaceLg),
                  if (_mode == AuthMode.signUp) ...<Widget>[
                    TextField(
                      controller: _name,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: strings(StringKey.authName),
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: AppTokens.spaceMd),
                  ],
                  if (_mode != AuthMode.passwordRecovery) ...<Widget>[
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: strings(StringKey.authEmail),
                        prefixIcon: const Icon(Icons.mail_outline),
                      ),
                    ),
                    const SizedBox(height: AppTokens.spaceMd),
                  ],
                  if (_mode != AuthMode.forgotPassword)
                    TextField(
                      controller: _password,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (String _) => _submit(),
                      decoration: InputDecoration(
                        labelText: strings(
                          _mode == AuthMode.passwordRecovery
                              ? StringKey.authNewPassword
                              : StringKey.authPassword,
                        ),
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: AppTokens.spaceLg),
                  FilledButton(
                    onPressed: auth.isBusy ? null : _submit,
                    child: auth.isBusy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(strings(_actionKey)),
                  ),
                  const SizedBox(height: AppTokens.spaceMd),
                  ..._secondaryActions(strings),
                  if (_mode == AuthMode.signUp) ...<Widget>[
                    const SizedBox(height: AppTokens.spaceMd),
                    Text(
                      strings(StringKey.authNoVerification),
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _secondaryActions(AppStrings strings) => switch (_mode) {
    AuthMode.signIn => <Widget>[
      TextButton(
        onPressed: () => _setMode(AuthMode.forgotPassword),
        child: Text(strings(StringKey.authForgotPrompt)),
      ),
      TextButton(
        onPressed: () => _setMode(AuthMode.signUp),
        child: Text(strings(StringKey.authNoAccount)),
      ),
    ],
    AuthMode.signUp => <Widget>[
      TextButton(
        onPressed: () => _setMode(AuthMode.signIn),
        child: Text(strings(StringKey.authHaveAccount)),
      ),
    ],
    AuthMode.forgotPassword => <Widget>[
      TextButton(
        onPressed: () => _setMode(AuthMode.signIn),
        child: Text(strings(StringKey.back)),
      ),
    ],
    AuthMode.passwordRecovery => const <Widget>[],
  };

  StringKey get _titleKey => switch (_mode) {
    AuthMode.signIn => StringKey.authSignInTitle,
    AuthMode.signUp => StringKey.authSignUpTitle,
    AuthMode.forgotPassword => StringKey.authForgotTitle,
    AuthMode.passwordRecovery => StringKey.authRecoveryTitle,
  };

  StringKey get _actionKey => switch (_mode) {
    AuthMode.signIn => StringKey.authSignIn,
    AuthMode.signUp => StringKey.authSignUp,
    AuthMode.forgotPassword => StringKey.authSendResetLink,
    AuthMode.passwordRecovery => StringKey.authUpdatePassword,
  };

  void _announce(String message, {bool isError = false}) {
    if (!mounted) return;
    final ThemeData theme = Theme.of(context);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 6),
          backgroundColor: isError ? theme.colorScheme.error : null,
        ),
      );
  }
}
