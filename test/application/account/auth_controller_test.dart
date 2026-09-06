import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/application/account/auth_controller.dart';
import 'package:humsukhan/core/failure/failure.dart';
import 'package:humsukhan/domain/account/account.dart';
import 'package:humsukhan/domain/account/auth_port.dart';

import '../../fakes/fake_app_ports.dart';

void main() {
  late FakeAuthPort port;
  late AuthController controller;

  setUp(() {
    port = FakeAuthPort();
    controller = AuthController(port: port);
  });

  tearDown(() async {
    await controller.dispose();
    await port.dispose();
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  group('restoring a session', () {
    test('starts as restoring, not as signed out', () {
      expect(controller.state.phase, AuthPhase.restoring);
    });

    test('no stored session means signed out', () async {
      await controller.initialise();
      expect(controller.state.phase, AuthPhase.signedOut);
    });

    test('a stored session signs the user straight in', () async {
      port.storedSession = const Account(id: 'u1', email: 'sana@example.com');
      await controller.initialise();

      expect(controller.state.phase, AuthPhase.signedIn);
      expect(controller.state.account?.email, 'sana@example.com');
    });

    test('a restore failure lands on signed out with a reason', () async {
      port.nextFailure = const AuthFailure(FailureCode.network);
      await controller.initialise();

      expect(controller.state.phase, AuthPhase.signedOut);
      expect(controller.state.failure?.code, FailureCode.network);
    });
  });

  group('validation happens before the network', () {
    test('an invalid email never reaches the port', () async {
      await controller.signIn(email: 'not-an-email', password: 'password123');

      expect(controller.state.failure?.code, FailureCode.authInvalidEmail);
      expect(controller.state.phase, isNot(AuthPhase.signedIn));
    });

    test(
      'a short password is rejected on sign up with a specific reason',
      () async {
        await controller.signUp(email: 'sana@example.com', password: 'short');

        expect(controller.state.failure?.code, FailureCode.authWeakPassword);
        expect(controller.state.failure?.remedy, contains('8'));
      },
    );

    test('an empty password on sign in is invalid input', () async {
      await controller.signIn(email: 'sana@example.com', password: '');
      expect(controller.state.failure?.code, FailureCode.invalidInput);
    });
  });

  group('signing in and up', () {
    test(
      'a successful sign in ends signed in, with no notice to dismiss',
      () async {
        await controller.signIn(
          email: 'sana@example.com',
          password: 'password123',
        );

        expect(controller.state.phase, AuthPhase.signedIn);
        expect(controller.state.isBusy, isFalse);
        expect(
          controller.state.notice,
          isNull,
          reason:
              'landing in the app is the feedback; a message here would sit '
              'over the screen it just revealed',
        );
      },
    );

    test('sign up needs no email verification step', () async {
      await controller.signUp(
        email: 'new@example.com',
        password: 'password123',
        displayName: 'Sana',
      );

      expect(controller.state.phase, AuthPhase.signedIn);
      expect(controller.state.account?.displayName, 'Sana');
    });

    test('a wrong password reports exactly that', () async {
      port.nextFailure = const AuthFailure(FailureCode.authInvalidCredentials);

      await controller.signIn(
        email: 'sana@example.com',
        password: 'password123',
      );

      expect(
        controller.state.failure?.code,
        FailureCode.authInvalidCredentials,
      );
      expect(controller.state.phase, isNot(AuthPhase.signedIn));
      expect(controller.state.isBusy, isFalse);
    });

    test('a second sign in while one is in flight is refused', () async {
      final Future<void> first = controller.signIn(
        email: 'sana@example.com',
        password: 'password123',
      );
      final Future<void> second = controller.signIn(
        email: 'sana@example.com',
        password: 'password123',
      );
      await Future.wait<void>(<Future<void>>[first, second]);

      expect(controller.state.phase, AuthPhase.signedIn);
    });
  });

  group('password reset', () {
    test('a reset request reports that the mail went', () async {
      await controller.sendPasswordReset('sana@example.com');

      expect(controller.state.notice, AuthNotice.resetLinkSent);
      expect(port.resetRequests.single, 'sana@example.com');
    });

    test('an invalid address is caught locally', () async {
      await controller.sendPasswordReset('nope');

      expect(controller.state.failure?.code, FailureCode.authInvalidEmail);
      expect(port.resetRequests, isEmpty);
    });

    test(
      'a recovery event moves the gate to the new-password screen',
      () async {
        await controller.initialise();
        port.emit(const PasswordRecovery());
        await settle();

        expect(controller.state.phase, AuthPhase.passwordRecovery);
      },
    );

    test('a short new password is refused before the round trip', () async {
      await controller.updatePassword('abc');

      expect(controller.state.failure?.code, FailureCode.authWeakPassword);
      expect(port.passwordUpdates, isEmpty);
    });

    test('a valid new password reports success', () async {
      await controller.updatePassword('a-good-password');

      expect(controller.state.notice, AuthNotice.passwordUpdated);
    });
  });

  group('signing out', () {
    test('signing out clears the account entirely', () async {
      await controller.signIn(
        email: 'sana@example.com',
        password: 'password123',
      );
      await controller.signOut();

      expect(controller.state.phase, AuthPhase.signedOut);
      expect(
        controller.state.account,
        isNull,
        reason: 'a switched user must not inherit the previous account',
      );
    });

    test('a sign-out failure keeps the user signed in and says why', () async {
      await controller.signIn(
        email: 'sana@example.com',
        password: 'password123',
      );
      port.nextFailure = const AuthFailure(FailureCode.network);

      await controller.signOut();

      expect(controller.state.phase, AuthPhase.signedIn);
      expect(controller.state.failure?.code, FailureCode.network);
    });
  });

  group('display name', () {
    test('an empty name is refused', () async {
      await controller.signIn(
        email: 'sana@example.com',
        password: 'password123',
      );
      await controller.updateDisplayName('  ');

      expect(controller.state.failure?.code, FailureCode.invalidInput);
    });

    test('a valid name is applied', () async {
      await controller.signIn(
        email: 'sana@example.com',
        password: 'password123',
      );
      await controller.updateDisplayName('Sana');

      expect(controller.state.account?.displayName, 'Sana');
    });
  });

  test('a signed-out event from the backend is honoured', () async {
    // The gate subscribes during initialise, which the composition root always
    // runs before any screen can sign in.
    await controller.initialise();
    await controller.signIn(email: 'sana@example.com', password: 'password123');
    port.emit(const SignedOut());
    await settle();

    expect(controller.state.phase, AuthPhase.signedOut);
    expect(controller.state.account, isNull);
  });
}
