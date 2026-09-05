import 'dart:async';

import 'package:humsukhan/core/failure/failure.dart';
import 'package:humsukhan/core/logging/app_logger.dart';
import 'package:humsukhan/core/result/result.dart';
import 'package:humsukhan/domain/account/account.dart' as domain;
import 'package:humsukhan/domain/account/auth_port.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// Accounts and sessions on Supabase.
///
/// Email verification is deliberately not required: the product decision is that
/// a Deaf user should not be blocked at the door by a mail round trip
/// (design.md §5.2).
final class SupabaseAuthAdapter implements AuthPort {
  /// Creates an adapter over [client].
  SupabaseAuthAdapter({
    required sb.SupabaseClient client,
    AppLogger logger = const SilentLogger(),
  }) : _client = client,
       _logger = logger {
    _subscription = _client.auth.onAuthStateChange.listen(
      _onAuthChange,
      onError: (Object error, StackTrace stackTrace) {
        _logger.log(
          LogLevel.error,
          'auth',
          'auth state stream error',
          error: error,
          stackTrace: stackTrace,
        );
        if (!_events.isClosed) _events.addError(error, stackTrace);
      },
    );
  }

  final sb.SupabaseClient _client;
  final AppLogger _logger;

  final StreamController<AuthEvent> _events =
      StreamController<AuthEvent>.broadcast();
  StreamSubscription<sb.AuthState>? _subscription;

  @override
  Stream<AuthEvent> get events => _events.stream;

  @override
  domain.Account? get currentAccount => _toAccount(_client.auth.currentUser);

  @override
  Future<Result<domain.Account?, AuthFailure>> restore() async {
    try {
      final sb.User? user = _client.auth.currentUser;
      return Ok<domain.Account?, AuthFailure>(_toAccount(user));
    } on Object catch (error, stackTrace) {
      return _failure<domain.Account?>(error, stackTrace);
    }
  }

  @override
  Future<Result<domain.Account, AuthFailure>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final sb.AuthResponse response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final domain.Account? account = _toAccount(response.user);
      if (account == null) {
        return const Err<domain.Account, AuthFailure>(
          AuthFailure(FailureCode.authInvalidCredentials),
        );
      }
      return Ok<domain.Account, AuthFailure>(account);
    } on Object catch (error, stackTrace) {
      return _failure<domain.Account>(error, stackTrace);
    }
  }

  @override
  Future<Result<domain.Account, AuthFailure>> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final sb.AuthResponse response = await _client.auth.signUp(
        email: email,
        password: password,
        data: displayName == null
            ? null
            : <String, Object?>{'display_name': displayName},
      );
      final domain.Account? account = _toAccount(response.user);
      if (account == null) {
        return const Err<domain.Account, AuthFailure>(
          AuthFailure(
            FailureCode.authNoSession,
            detail: 'sign up returned no session',
          ),
        );
      }
      return Ok<domain.Account, AuthFailure>(account);
    } on Object catch (error, stackTrace) {
      return _failure<domain.Account>(error, stackTrace);
    }
  }

  @override
  Future<Result<Unit, AuthFailure>> signOut() async {
    try {
      await _client.auth.signOut();
      return const Ok<Unit, AuthFailure>(unit);
    } on Object catch (error, stackTrace) {
      return _failure<Unit>(error, stackTrace);
    }
  }

  @override
  Future<Result<Unit, AuthFailure>> sendPasswordReset(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
      return const Ok<Unit, AuthFailure>(unit);
    } on Object catch (error, stackTrace) {
      return _failure<Unit>(error, stackTrace);
    }
  }

  @override
  Future<Result<Unit, AuthFailure>> updatePassword(String password) async {
    try {
      await _client.auth.updateUser(sb.UserAttributes(password: password));
      return const Ok<Unit, AuthFailure>(unit);
    } on Object catch (error, stackTrace) {
      return _failure<Unit>(error, stackTrace);
    }
  }

  @override
  Future<Result<domain.Account, AuthFailure>> updateDisplayName(
    String displayName,
  ) async {
    try {
      final sb.UserResponse response = await _client.auth.updateUser(
        sb.UserAttributes(data: <String, Object?>{'display_name': displayName}),
      );
      final domain.Account? account = _toAccount(response.user);
      if (account == null) {
        return const Err<domain.Account, AuthFailure>(
          AuthFailure(FailureCode.authNoSession),
        );
      }
      return Ok<domain.Account, AuthFailure>(account);
    } on Object catch (error, stackTrace) {
      return _failure<domain.Account>(error, stackTrace);
    }
  }

  /// Stops listening to session changes.
  Future<void> dispose() async {
    await _subscription?.cancel();
    await _events.close();
  }

  void _onAuthChange(sb.AuthState state) {
    if (_events.isClosed) return;
    switch (state.event) {
      case sb.AuthChangeEvent.passwordRecovery:
        _events.add(const PasswordRecovery());
      case sb.AuthChangeEvent.signedOut:
        _events.add(const SignedOut());
      case sb.AuthChangeEvent.signedIn:
      case sb.AuthChangeEvent.userUpdated:
      case sb.AuthChangeEvent.tokenRefreshed:
      case sb.AuthChangeEvent.initialSession:
        final domain.Account? account = _toAccount(state.session?.user);
        _events.add(account == null ? const SignedOut() : SignedIn(account));
      case sb.AuthChangeEvent.mfaChallengeVerified:
        break;
      // The enum carries a deprecated member; the default keeps this switch
      // exhaustive without naming it.
      default:
        break;
    }
  }

  domain.Account? _toAccount(sb.User? user) {
    if (user == null) return null;
    final Object? name = user.userMetadata?['display_name'];
    return domain.Account(
      id: user.id,
      email: user.email ?? '',
      displayName: name is String && name.trim().isNotEmpty ? name : null,
    );
  }

  /// Maps a provider exception onto a failure the user can act on.
  ///
  /// Never `null` and never a rethrow: the call site always gets something with
  /// a message and a remedy.
  Result<T, AuthFailure> _failure<T>(Object error, StackTrace stackTrace) {
    _logger.log(
      LogLevel.warning,
      'auth',
      'request failed',
      error: error,
      stackTrace: stackTrace,
    );
    if (error is sb.AuthException) {
      final String message = error.message.toLowerCase();
      final FailureCode code;
      if (message.contains('invalid login') ||
          message.contains('invalid credentials')) {
        code = FailureCode.authInvalidCredentials;
      } else if (message.contains('already registered') ||
          message.contains('already been registered') ||
          message.contains('user already exists')) {
        code = FailureCode.authEmailInUse;
      } else if (message.contains('password') && message.contains('least')) {
        code = FailureCode.authWeakPassword;
      } else if (message.contains('rate limit') ||
          message.contains('too many')) {
        code = FailureCode.authRateLimited;
      } else if (message.contains('email') && message.contains('invalid')) {
        code = FailureCode.authInvalidEmail;
      } else if (error.statusCode == '401' || error.statusCode == '403') {
        code = FailureCode.authNoSession;
      } else {
        code = FailureCode.unknown;
      }
      return Err<T, AuthFailure>(AuthFailure(code, detail: error.message));
    }
    return Err<T, AuthFailure>(
      AuthFailure(FailureCode.network, detail: '$error'),
    );
  }
}
