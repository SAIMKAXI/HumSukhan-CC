import 'package:humsukhan/core/failure/failure.dart';
import 'package:humsukhan/core/result/result.dart';
import 'package:humsukhan/domain/account/account.dart';

/// An authentication failure.
final class AuthFailure extends Failure {
  /// Creates an auth failure for [code].
  const AuthFailure(
    FailureCode code, {
    super.detail,
    super.isRecoverable = true,
  }) : super(code: code);
}

/// What the session is doing.
sealed class AuthEvent {
  const AuthEvent();
}

/// A user is signed in.
final class SignedIn extends AuthEvent {
  /// Creates a signed-in event.
  const SignedIn(this.account);

  /// Who.
  final Account account;
}

/// No user is signed in.
final class SignedOut extends AuthEvent {
  /// Creates a signed-out event.
  const SignedOut();
}

/// The user followed a password-recovery link and must choose a new password.
final class PasswordRecovery extends AuthEvent {
  /// Creates a recovery event.
  const PasswordRecovery();
}

/// Accounts and sessions.
///
/// There is no mandatory email verification: a deliberate product decision
/// (design.md §5.2).
abstract interface class AuthPort {
  /// Session changes, including the initial restore.
  Stream<AuthEvent> get events;

  /// The account signed in right now, when there is one.
  Account? get currentAccount;

  /// Restores a persisted session, if any.
  Future<Result<Account?, AuthFailure>> restore();

  /// Signs in with [email] and [password].
  Future<Result<Account, AuthFailure>> signIn({
    required String email,
    required String password,
  });

  /// Creates an account and signs it in.
  Future<Result<Account, AuthFailure>> signUp({
    required String email,
    required String password,
    String? displayName,
  });

  /// Ends the session.
  Future<Result<Unit, AuthFailure>> signOut();

  /// Sends a password-reset email to [email].
  Future<Result<Unit, AuthFailure>> sendPasswordReset(String email);

  /// Sets a new password for the recovering session.
  Future<Result<Unit, AuthFailure>> updatePassword(String password);

  /// Changes the display name on the current account.
  Future<Result<Account, AuthFailure>> updateDisplayName(String displayName);
}
