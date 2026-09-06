import 'dart:async';

import 'package:humsukhan/core/failure/failure.dart';
import 'package:humsukhan/core/id/id_generator.dart';
import 'package:humsukhan/core/logging/app_logger.dart';
import 'package:humsukhan/core/result/result.dart';
import 'package:humsukhan/domain/account/account.dart';
import 'package:humsukhan/domain/account/auth_port.dart';
import 'package:humsukhan/infrastructure/storage/key_value_store.dart';

/// The account a build with no backend runs on.
///
/// Without this, a build whose Supabase configuration is missing shows a
/// sign-in screen that can never succeed: every credential is refused, and
/// there is no way past it to the captions the app exists to provide. An
/// accessibility tool that cannot be opened is worse than one with no account
/// system at all, so when there is no server to sign in to, the app signs the
/// user in to their own phone instead.
///
/// This is not a weaker version of the real thing and does not pretend to be
/// one. There is no password, because there is nothing remote to protect; the
/// account exists to give the per-user stores a stable key so data stays
/// scoped exactly as it is for a real account. Nothing here ever runs when a
/// backend is configured — that path is [SupabaseAuthAdapter], untouched.
final class DeviceAuthAdapter implements AuthPort {
  /// Creates an adapter over [store].
  DeviceAuthAdapter({
    required KeyValueStore store,
    required IdGenerator ids,
    AppLogger logger = const SilentLogger(),
  }) : _store = store,
       _ids = ids,
       _logger = logger;

  /// Where the device account's identity is kept.
  static const String idKey = 'account.device.id';

  /// Where the chosen display name is kept.
  static const String nameKey = 'account.device.name';

  /// The address shown for a device account.
  ///
  /// A reserved, non-routable domain: it can never collide with somebody's
  /// real address, and it cannot be mistaken for one that receives mail.
  static const String localEmail = 'you@this-device.humsukhan.invalid';

  final KeyValueStore _store;
  final IdGenerator _ids;
  final AppLogger _logger;

  final StreamController<AuthEvent> _events =
      StreamController<AuthEvent>.broadcast();

  Account? _account;

  @override
  Stream<AuthEvent> get events => _events.stream;

  @override
  Account? get currentAccount => _account;

  @override
  Future<Result<Account?, AuthFailure>> restore() async {
    try {
      String? id = await _store.read(idKey);
      if (id == null || id.isEmpty) {
        id = _ids.next();
        await _store.write(idKey, id);
      }
      final String? name = await _store.read(nameKey);
      final Account account = Account(
        id: id,
        email: localEmail,
        displayName: (name == null || name.trim().isEmpty) ? null : name,
        isLocal: true,
      );
      _account = account;
      _emit(SignedIn(account));
      return Ok<Account?, AuthFailure>(account);
    } on Object catch (error, stackTrace) {
      // The store is the only thing that can fail here, and if it has, the
      // per-user scoping it provides is gone too. Failing loudly is right.
      _logger.log(
        LogLevel.error,
        'auth',
        'device account could not be read',
        error: error,
        stackTrace: stackTrace,
      );
      return const Err<Account?, AuthFailure>(
        AuthFailure(FailureCode.storageReadFailed),
      );
    }
  }

  @override
  Future<Result<Account, AuthFailure>> signIn({
    required String email,
    required String password,
  }) async => _alreadyHere();

  @override
  Future<Result<Account, AuthFailure>> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async => _alreadyHere();

  /// Signing out of a device account is refused rather than faked.
  ///
  /// There is nowhere to sign out *to*: doing it would strand the user on a
  /// sign-in screen no password can pass, and orphan their saved
  /// conversations behind an account id they can no longer reach.
  @override
  Future<Result<Unit, AuthFailure>> signOut() async =>
      const Err<Unit, AuthFailure>(
        AuthFailure(FailureCode.backendUnavailable, isRecoverable: false),
      );

  @override
  Future<Result<Unit, AuthFailure>> sendPasswordReset(String email) async =>
      const Err<Unit, AuthFailure>(
        AuthFailure(FailureCode.backendUnavailable, isRecoverable: false),
      );

  @override
  Future<Result<Unit, AuthFailure>> updatePassword(String password) async =>
      const Err<Unit, AuthFailure>(
        AuthFailure(FailureCode.backendUnavailable, isRecoverable: false),
      );

  /// The one piece of account management that is genuinely local.
  @override
  Future<Result<Account, AuthFailure>> updateDisplayName(
    String displayName,
  ) async {
    final Account? current = _account;
    if (current == null) {
      return const Err<Account, AuthFailure>(
        AuthFailure(FailureCode.authNoSession),
      );
    }
    final String trimmed = displayName.trim();
    try {
      if (trimmed.isEmpty) {
        await _store.remove(nameKey);
      } else {
        await _store.write(nameKey, trimmed);
      }
    } on Object catch (error) {
      _logger.log(LogLevel.warning, 'auth', 'name not saved', error: error);
      return const Err<Account, AuthFailure>(
        AuthFailure(FailureCode.storageWriteFailed),
      );
    }
    final Account updated = current.withDisplayName(
      trimmed.isEmpty ? null : trimmed,
    );
    _account = updated;
    _emit(SignedIn(updated));
    return Ok<Account, AuthFailure>(updated);
  }

  /// Releases the adapter.
  Future<void> dispose() async {
    if (!_events.isClosed) await _events.close();
  }

  Result<Account, AuthFailure> _alreadyHere() {
    final Account? account = _account;
    if (account == null) {
      return const Err<Account, AuthFailure>(
        AuthFailure(FailureCode.backendUnavailable, isRecoverable: false),
      );
    }
    return Ok<Account, AuthFailure>(account);
  }

  void _emit(AuthEvent event) {
    if (!_events.isClosed) _events.add(event);
  }
}
