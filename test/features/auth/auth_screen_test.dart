import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/core/failure/failure.dart';
import 'package:humsukhan/core/l10n/app_language.dart';
import 'package:humsukhan/core/l10n/app_strings.dart';
import 'package:humsukhan/domain/account/auth_port.dart';
import 'package:humsukhan/features/auth/auth_screen.dart';

import '../../fakes/fake_app_ports.dart';
import '../../support/harness.dart';

void main() {
  Future<void> pumpAuth(
    WidgetTester tester, {
    FakeAuthPort? auth,
    AuthMode mode = AuthMode.signIn,
    AppLanguage language = AppLanguage.english,
  }) async {
    await tester.pumpWidget(
      harness(
        child: AuthScreen(initialMode: mode),
        auth: auth,
        language: language,
      ),
    );
    await tester.pumpAndSettle();
  }

  group('sign in', () {
    testWidgets('shows email, password and a way to sign up', (
      WidgetTester tester,
    ) async {
      await pumpAuth(tester);

      expect(find.text(english(StringKey.authSignInTitle)), findsOneWidget);
      expect(find.text(english(StringKey.authNoAccount)), findsOneWidget);
      expect(find.text(english(StringKey.authForgotPrompt)), findsOneWidget);
    });

    testWidgets('an invalid email is reported specifically, not as "error"', (
      WidgetTester tester,
    ) async {
      await pumpAuth(tester);

      await tester.enterText(find.byType(TextField).first, 'not-an-email');
      await tester.enterText(find.byType(TextField).last, 'password123');
      await tester.tap(
        find.widgetWithText(FilledButton, english(StringKey.authSignIn)),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.textContaining(
          english.failureMessage(FailureCode.authInvalidEmail),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a wrong password says exactly that', (
      WidgetTester tester,
    ) async {
      final FakeAuthPort auth = FakeAuthPort()
        ..nextFailure = const AuthFailure(FailureCode.authInvalidCredentials);
      await pumpAuth(tester, auth: auth);

      await tester.enterText(find.byType(TextField).first, 'sana@example.com');
      await tester.enterText(find.byType(TextField).last, 'password123');
      await tester.tap(
        find.widgetWithText(FilledButton, english(StringKey.authSignIn)),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.textContaining(
          english.failureMessage(FailureCode.authInvalidCredentials),
        ),
        findsOneWidget,
      );
    });
  });

  group('sign up', () {
    testWidgets('says no email verification is needed', (
      WidgetTester tester,
    ) async {
      await pumpAuth(tester, mode: AuthMode.signUp);

      expect(find.text(english(StringKey.authNoVerification)), findsOneWidget);
    });

    testWidgets('a short password names the minimum length', (
      WidgetTester tester,
    ) async {
      await pumpAuth(tester, mode: AuthMode.signUp);

      final Finder fields = find.byType(TextField);
      await tester.enterText(fields.at(1), 'sana@example.com');
      await tester.enterText(fields.at(2), 'short');
      await tester.tap(
        find.widgetWithText(FilledButton, english(StringKey.authSignUp)),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.textContaining(
          english.failureRemedy(FailureCode.authWeakPassword)!,
        ),
        findsOneWidget,
      );
    });
  });

  group('password reset', () {
    testWidgets('sending a reset link confirms it went', (
      WidgetTester tester,
    ) async {
      await pumpAuth(tester, mode: AuthMode.forgotPassword);

      await tester.enterText(find.byType(TextField).first, 'sana@example.com');
      await tester.tap(
        find.widgetWithText(FilledButton, english(StringKey.authSendResetLink)),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text(english(StringKey.authResetSent)), findsOneWidget);
    });

    testWidgets('the recovery form asks for a new password only', (
      WidgetTester tester,
    ) async {
      await pumpAuth(tester, mode: AuthMode.passwordRecovery);

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text(english(StringKey.authUpdatePassword)), findsOneWidget);
    });
  });

  group('both languages', () {
    testWidgets('the whole screen renders in Urdu', (
      WidgetTester tester,
    ) async {
      await pumpAuth(tester, language: AppLanguage.urdu);

      expect(find.text(urdu(StringKey.authSignInTitle)), findsOneWidget);
      expect(find.text(urdu(StringKey.authSignIn)), findsOneWidget);
    });
  });
}
