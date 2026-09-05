import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/core/failure/failure.dart';
import 'package:humsukhan/domain/account/account.dart';
import 'package:humsukhan/domain/account/credentials.dart';

void main() {
  group('email validation says what is wrong, not just "error"', () {
    test('accepts an ordinary address', () {
      expect(Credentials.validateEmail('sana@example.com'), isNull);
    });

    test('rejects an empty address', () {
      expect(Credentials.validateEmail('  '), FailureCode.authInvalidEmail);
    });

    test('rejects an address with no domain', () {
      expect(Credentials.validateEmail('sana@'), FailureCode.authInvalidEmail);
    });

    test('rejects an address with no local part', () {
      expect(
        Credentials.validateEmail('@example.com'),
        FailureCode.authInvalidEmail,
      );
    });
  });

  group('password validation', () {
    test('accepts a password at the minimum length', () {
      expect(Credentials.validatePassword('12345678'), isNull);
    });

    test('names weakness rather than failing generically', () {
      expect(
        Credentials.validatePassword('short'),
        FailureCode.authWeakPassword,
      );
    });

    test('an empty password is invalid input, not a weak password', () {
      expect(Credentials.validatePassword(''), FailureCode.invalidInput);
    });
  });

  group('greeting name', () {
    test('prefers the display name', () {
      const Account account = Account(
        id: 'u1',
        email: 'sana@example.com',
        displayName: 'Sana',
      );
      expect(account.greetingName, 'Sana');
    });

    test('falls back to the local part of the email', () {
      const Account account = Account(id: 'u1', email: 'sana@example.com');
      expect(account.greetingName, 'sana');
    });

    test('ignores a blank display name', () {
      const Account account = Account(
        id: 'u1',
        email: 'sana@example.com',
        displayName: '   ',
      );
      expect(account.greetingName, 'sana');
    });
  });
}
