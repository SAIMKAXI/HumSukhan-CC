import 'dart:async';

import 'package:humsukhan/core/failure/failure.dart';
import 'package:humsukhan/core/result/result.dart';
import 'package:humsukhan/domain/account/account.dart';
import 'package:humsukhan/domain/account/auth_port.dart';
import 'package:humsukhan/domain/professional/insight.dart';
import 'package:humsukhan/domain/professional/insight_port.dart';
import 'package:humsukhan/domain/speech/language_tag.dart';
import 'package:humsukhan/domain/speech/speech_failure.dart';
import 'package:humsukhan/infrastructure/stt/recognition_token.dart';

/// Stand-ins used when the build has no backend configured.
///
/// They exist so a misconfigured build fails *visibly and specifically* at the
/// point of use, rather than appearing to work or crashing. Nothing here
/// pretends to succeed.
final class UnavailableAuthPort implements AuthPort {
  /// Creates the port.
  UnavailableAuthPort();

  static const AuthFailure _failure = AuthFailure(
    FailureCode.backendUnavailable,
    isRecoverable: false,
  );

  final StreamController<AuthEvent> _events =
      StreamController<AuthEvent>.broadcast();

  @override
  Account? get currentAccount => null;

  @override
  Stream<AuthEvent> get events => _events.stream;

  @override
  Future<Result<Account?, AuthFailure>> restore() async =>
      const Ok<Account?, AuthFailure>(null);

  @override
  Future<Result<Account, AuthFailure>> signIn({
    required String email,
    required String password,
  }) async => const Err<Account, AuthFailure>(_failure);

  @override
  Future<Result<Account, AuthFailure>> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async => const Err<Account, AuthFailure>(_failure);

  @override
  Future<Result<Unit, AuthFailure>> signOut() async =>
      const Ok<Unit, AuthFailure>(unit);

  @override
  Future<Result<Unit, AuthFailure>> sendPasswordReset(String email) async =>
      const Err<Unit, AuthFailure>(_failure);

  @override
  Future<Result<Unit, AuthFailure>> updatePassword(String password) async =>
      const Err<Unit, AuthFailure>(_failure);

  @override
  Future<Result<Account, AuthFailure>> updateDisplayName(
    String displayName,
  ) async => const Err<Account, AuthFailure>(_failure);

  /// Closes the event stream.
  Future<void> dispose() => _events.close();
}

/// Refuses to mint recognition tokens, saying why.
final class UnavailableTokenSource implements RecognitionTokenSource {
  /// Creates the source.
  const UnavailableTokenSource();

  @override
  Future<Result<RecognitionToken, SttFailure>> fetch() async =>
      const Err<RecognitionToken, SttFailure>(
        SttFailure(FailureCode.backendUnavailable, isRecoverable: false),
      );
}

/// Refuses to summarise, saying why.
final class UnavailableInsightPort implements InsightPort {
  /// Creates the port.
  const UnavailableInsightPort();

  @override
  Future<Result<Insight, InsightFailure>> summarise({
    required String transcript,
    required LanguageTag language,
  }) async => const Err<Insight, InsightFailure>(
    InsightFailure(FailureCode.backendUnavailable, isRecoverable: false),
  );
}
