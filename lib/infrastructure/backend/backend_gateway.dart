import 'package:humsukhan/core/failure/failure.dart';
import 'package:humsukhan/core/result/result.dart';

/// A backend failure.
final class BackendFailure extends Failure {
  /// Creates a backend failure for [code].
  const BackendFailure(
    FailureCode code, {
    super.detail,
    super.isRecoverable = true,
  }) : super(code: code);
}

/// Calls server-side functions on the user's behalf.
///
/// This is the only path to a third-party provider. The client holds no
/// provider credential; the function does, and returns either a result or a
/// short-lived token.
abstract interface class BackendGateway {
  /// Invokes the Edge Function [name] with [body].
  Future<Result<Map<String, Object?>, BackendFailure>> invoke(
    String name, {
    Map<String, Object?> body = const <String, Object?>{},
  });
}
