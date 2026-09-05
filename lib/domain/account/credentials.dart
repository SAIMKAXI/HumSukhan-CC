import 'package:humsukhan/core/failure/failure.dart';

/// Client-side validation of what the user typed.
///
/// Pure, so the "enter a valid email" copy is a unit test rather than something
/// only reachable by tapping through a form.
abstract final class Credentials {
  /// The shortest password the app accepts.
  static const int minimumPasswordLength = 8;

  static final RegExp _email = RegExp(
    r'^[\w.!#$%&*+/=?^`{|}~-]+@[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?'
    r'(\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$',
  );

  /// Why [email] is unacceptable, or `null` when it is fine.
  static FailureCode? validateEmail(String email) {
    final String trimmed = email.trim();
    if (trimmed.isEmpty) return FailureCode.authInvalidEmail;
    if (!_email.hasMatch(trimmed)) return FailureCode.authInvalidEmail;
    return null;
  }

  /// Why [password] is unacceptable, or `null` when it is fine.
  static FailureCode? validatePassword(String password) {
    if (password.isEmpty) return FailureCode.invalidInput;
    if (password.length < minimumPasswordLength) {
      return FailureCode.authWeakPassword;
    }
    return null;
  }
}
