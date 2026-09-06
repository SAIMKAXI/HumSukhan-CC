import 'dart:async';

import 'package:humsukhan/core/failure/failure.dart';
import 'package:humsukhan/core/logging/app_logger.dart';
import 'package:humsukhan/core/result/result.dart';
import 'package:humsukhan/domain/account/account.dart';
import 'package:humsukhan/domain/account/auth_port.dart';
import 'package:humsukhan/domain/account/credentials.dart';

/// Where the account gate is.
enum AuthPhase {
  /// The stored session has not been checked yet.
  restoring,

  /// No user.
  signedOut,

  /// A user.
  signedIn,

  /// The user followed a recovery link and must set a new password.
  passwordRecovery,
}

/// What the auth screens render.
final class AuthState {
  /// Creates an auth state.
  const AuthState({
    this.phase = AuthPhase.restoring,
    this.account,
    this.failure,
    this.isBusy = false,
    this.notice,
  });

  /// Where the gate is.
  final AuthPhase phase;

  /// Who is signed in, when anyone is.
  final Account? account;

  /// The most recent failure, until it is acknowledged.
  final Failure? failure;

  /// Whether a request is in flight.
  final bool isBusy;

  /// A one-shot success message ("check your email"), until acknowledged.
  final AuthNotice? notice;

  /// A copy with the given fields replaced.
  AuthState copyWith({
    AuthPhase? phase,
    Account? account,
    bool clearAccount = false,
    Failure? failure,
    bool clearFailure = false,
    bool? isBusy,
    AuthNotice? notice,
    bool clearNotice = false,
  }) => AuthState(
    phase: phase ?? this.phase,
    account: clearAccount ? null : (account ?? this.account),
    failure: clearFailure ? null : (failure ?? this.failure),
    isBusy: isBusy ?? this.isBusy,
    notice: clearNotice ? null : (notice ?? this.notice),
  );
}

/// Something that went right and the user should be told about.
enum AuthNotice {
  /// A reset link was sent.
  resetLinkSent,

  /// The password was changed.
  passwordUpdated,
}

/// Sign in, sign up, sign out, reset, restore.
///
/// Validates before calling the port, so "enter a valid email" is produced
/// locally and instantly rather than as a round trip.
final class AuthController {
  /// Creates a controller over [port].
  AuthController({
    required AuthPort port,
    AppLogger logger = const SilentLogger(),
  }) : _port = port,
       _logger = logger;

  final AuthPort _port;
  final AppLogger _logger;

  final StreamController<AuthState> _states =
      StreamController<AuthState>.broadcast();

  AuthState _state = const AuthState();
  StreamSubscription<AuthEvent>? _events;
  bool _disposed = false;
  bool _inFlight = false;

  /// The state right now.
  AuthState get state => _state;

  /// Every change to [state].
  Stream<AuthState> get states => _states.stream;

  /// Subscribes to session changes and restores any stored session.
  Future<void> initialise() async {
    if (_disposed) return;
    _events ??= _port.events.listen(
      _onAuthEvent,
      onError: (Object error, StackTrace stackTrace) {
        _logger.log(
          LogLevel.error,
          'auth',
          'auth event stream error',
          error: error,
          stackTrace: stackTrace,
        );
        if (_disposed) return;
        _emit(
          _state.copyWith(
            failure: AuthFailure(FailureCode.unknown, detail: '$error'),
          ),
        );
      },
    );

    final Result<Account?, AuthFailure> restored = await _port.restore();
    if (_disposed) return;
    restored.fold(
      (Account? account) => _emit(
        _state.copyWith(
          phase: account == null ? AuthPhase.signedOut : AuthPhase.signedIn,
          account: account,
          clearAccount: account == null,
        ),
      ),
      (AuthFailure failure) =>
          _emit(_state.copyWith(phase: AuthPhase.signedOut, failure: failure)),
    );
  }

  /// Signs in with [email] and [password].
  Future<Result<Account, AuthFailure>> signIn({
    required String email,
    required String password,
  }) => _run(() async {
    final FailureCode? emailProblem = Credentials.validateEmail(email);
    if (emailProblem != null) {
      return Err<Account, AuthFailure>(AuthFailure(emailProblem));
    }
    if (password.isEmpty) {
      return const Err<Account, AuthFailure>(
        AuthFailure(FailureCode.invalidInput),
      );
    }
    return _port.signIn(email: email.trim(), password: password);
  });

  /// Creates an account and signs in. No email verification is required.
  Future<Result<Account, AuthFailure>> signUp({
    required String email,
    required String password,
    String? displayName,
  }) => _run(() async {
    final FailureCode? emailProblem = Credentials.validateEmail(email);
    if (emailProblem != null) {
      return Err<Account, AuthFailure>(AuthFailure(emailProblem));
    }
    final FailureCode? passwordProblem = Credentials.validatePassword(password);
    if (passwordProblem != null) {
      return Err<Account, AuthFailure>(AuthFailure(passwordProblem));
    }
    return _port.signUp(
      email: email.trim(),
      password: password,
      displayName: displayName?.trim(),
    );
  });

  /// Ends the session.
  Future<Result<Unit, AuthFailure>> signOut() async {
    if (_disposed) {
      return const Err<Unit, AuthFailure>(
        AuthFailure(FailureCode.cancelled, isRecoverable: false),
      );
    }
    _emit(_state.copyWith(isBusy: true, clearFailure: true));
    final Result<Unit, AuthFailure> result = await _port.signOut();
    if (_disposed) return result;
    return result.fold(
      (Unit value) {
        _emit(const AuthState(phase: AuthPhase.signedOut));
        return Ok<Unit, AuthFailure>(value);
      },
      (AuthFailure failure) {
        _emit(_state.copyWith(isBusy: false, failure: failure));
        return Err<Unit, AuthFailure>(failure);
      },
    );
  }

  /// Sends a password-reset email.
  Future<Result<Unit, AuthFailure>> sendPasswordReset(String email) async {
    if (_disposed) {
      return const Err<Unit, AuthFailure>(
        AuthFailure(FailureCode.cancelled, isRecoverable: false),
      );
    }
    final FailureCode? problem = Credentials.validateEmail(email);
    if (problem != null) {
      final AuthFailure failure = AuthFailure(problem);
      _emit(_state.copyWith(failure: failure, isBusy: false));
      return Err<Unit, AuthFailure>(failure);
    }
    _emit(_state.copyWith(isBusy: true, clearFailure: true, clearNotice: true));
    final Result<Unit, AuthFailure> result = await _port.sendPasswordReset(
      email.trim(),
    );
    if (_disposed) return result;
    _emit(
      result.fold(
        (Unit _) =>
            _state.copyWith(isBusy: false, notice: AuthNotice.resetLinkSent),
        (AuthFailure failure) =>
            _state.copyWith(isBusy: false, failure: failure),
      ),
    );
    return result;
  }

  /// Sets a new password for a recovering session.
  Future<Result<Unit, AuthFailure>> updatePassword(String password) async {
    if (_disposed) {
      return const Err<Unit, AuthFailure>(
        AuthFailure(FailureCode.cancelled, isRecoverable: false),
      );
    }
    final FailureCode? problem = Credentials.validatePassword(password);
    if (problem != null) {
      final AuthFailure failure = AuthFailure(problem);
      _emit(_state.copyWith(failure: failure, isBusy: false));
      return Err<Unit, AuthFailure>(failure);
    }
    _emit(_state.copyWith(isBusy: true, clearFailure: true, clearNotice: true));
    final Result<Unit, AuthFailure> result = await _port.updatePassword(
      password,
    );
    if (_disposed) return result;
    _emit(
      result.fold(
        (Unit _) => _state.copyWith(
          isBusy: false,
          notice: AuthNotice.passwordUpdated,
          phase: _port.currentAccount == null
              ? AuthPhase.signedOut
              : AuthPhase.signedIn,
        ),
        (AuthFailure failure) =>
            _state.copyWith(isBusy: false, failure: failure),
      ),
    );
    return result;
  }

  /// Changes the display name on the signed-in account.
  Future<Result<Account, AuthFailure>> updateDisplayName(String name) async {
    if (_disposed) {
      return const Err<Account, AuthFailure>(
        AuthFailure(FailureCode.cancelled, isRecoverable: false),
      );
    }
    if (name.trim().isEmpty) {
      const AuthFailure failure = AuthFailure(FailureCode.invalidInput);
      _emit(_state.copyWith(failure: failure));
      return const Err<Account, AuthFailure>(failure);
    }
    _emit(_state.copyWith(isBusy: true, clearFailure: true));
    final Result<Account, AuthFailure> result = await _port.updateDisplayName(
      name.trim(),
    );
    if (_disposed) return result;
    _emit(
      result.fold(
        (Account account) => _state.copyWith(isBusy: false, account: account),
        (AuthFailure failure) =>
            _state.copyWith(isBusy: false, failure: failure),
      ),
    );
    return result;
  }

  /// Clears the current failure.
  void acknowledgeFailure() {
    if (_disposed || _state.failure == null) return;
    _emit(_state.copyWith(clearFailure: true));
  }

  /// Clears the current notice.
  void acknowledgeNotice() {
    if (_disposed || _state.notice == null) return;
    _emit(_state.copyWith(clearNotice: true));
  }

  /// Stops listening.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _events?.cancel();
    await _states.close();
  }

  /// Runs a sign-in or sign-up.
  ///
  /// Success raises no notice: the user lands in the app, and that is the
  /// feedback. A success message here would also sit over the screen it just
  /// revealed, covering the controls at the bottom of it.
  Future<Result<Account, AuthFailure>> _run(
    Future<Result<Account, AuthFailure>> Function() body,
  ) async {
    if (_disposed) {
      return const Err<Account, AuthFailure>(
        AuthFailure(FailureCode.cancelled, isRecoverable: false),
      );
    }
    if (_inFlight) {
      return const Err<Account, AuthFailure>(
        AuthFailure(FailureCode.cancelled, detail: 'already in flight'),
      );
    }
    _inFlight = true;
    _emit(_state.copyWith(isBusy: true, clearFailure: true, clearNotice: true));

    final Result<Account, AuthFailure> result = await body();
    _inFlight = false;
    if (_disposed) return result;

    _emit(
      result.fold(
        (Account account) => _state.copyWith(
          isBusy: false,
          phase: AuthPhase.signedIn,
          account: account,
        ),
        (AuthFailure failure) =>
            _state.copyWith(isBusy: false, failure: failure),
      ),
    );
    return result;
  }

  void _onAuthEvent(AuthEvent event) {
    if (_disposed) return;
    switch (event) {
      case SignedIn(:final Account account):
        _emit(_state.copyWith(phase: AuthPhase.signedIn, account: account));
      case SignedOut():
        _emit(const AuthState(phase: AuthPhase.signedOut));
      case PasswordRecovery():
        _emit(_state.copyWith(phase: AuthPhase.passwordRecovery));
    }
  }

  void _emit(AuthState next) {
    if (_disposed) return;
    _state = next;
    if (!_states.isClosed) _states.add(next);
  }
}
