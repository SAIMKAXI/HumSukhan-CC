import 'package:humsukhan/core/failure/failure.dart';
import 'package:humsukhan/core/result/result.dart';
import 'package:humsukhan/domain/speech/speech_failure.dart';
import 'package:humsukhan/infrastructure/backend/backend_gateway.dart';

/// A short-lived recognition credential.
///
/// The provider's real API key never leaves the Edge Function. This is what the
/// client gets, and it expires.
final class RecognitionToken {
  /// Creates a token.
  const RecognitionToken({required this.value, required this.expiresAt});

  /// The bearer value.
  final String value;

  /// When it stops working.
  final DateTime expiresAt;

  /// Whether it is worth using, allowing a margin for the handshake.
  bool isUsableAt(DateTime now) =>
      expiresAt.isAfter(now.add(const Duration(seconds: 5)));
}

/// Mints [RecognitionToken]s.
abstract interface class RecognitionTokenSource {
  /// A token that is valid now.
  Future<Result<RecognitionToken, SttFailure>> fetch();
}

/// Fetches tokens from an Edge Function.
final class BackendTokenSource implements RecognitionTokenSource {
  /// Creates a token source.
  BackendTokenSource({
    required BackendGateway gateway,
    required String functionName,
    DateTime Function()? now,
  }) : _gateway = gateway,
       _functionName = functionName,
       _now = now ?? DateTime.now;

  final BackendGateway _gateway;
  final String _functionName;
  final DateTime Function() _now;

  RecognitionToken? _cached;

  @override
  Future<Result<RecognitionToken, SttFailure>> fetch() async {
    final RecognitionToken? cached = _cached;
    if (cached != null && cached.isUsableAt(_now())) {
      return Ok<RecognitionToken, SttFailure>(cached);
    }

    final Result<Map<String, Object?>, BackendFailure> response = await _gateway
        .invoke(_functionName);

    return response.fold(
      (Map<String, Object?> body) {
        final Object? key = body['token'] ?? body['key'];
        if (key is! String || key.isEmpty) {
          return const Err<RecognitionToken, SttFailure>(
            SttFailure(
              FailureCode.sttAuthFailed,
              detail: 'token function returned no token',
            ),
          );
        }
        final Object? ttl = body['expires_in'];
        final Duration lifetime = Duration(
          seconds: ttl is num ? ttl.toInt() : 30,
        );
        final RecognitionToken token = RecognitionToken(
          value: key,
          expiresAt: _now().add(lifetime),
        );
        _cached = token;
        return Ok<RecognitionToken, SttFailure>(token);
      },
      (BackendFailure failure) {
        _cached = null;
        return Err<RecognitionToken, SttFailure>(
          SttFailure(
            failure.code == FailureCode.authNoSession
                ? FailureCode.sttAuthFailed
                : failure.code,
            detail: failure.detail,
          ),
        );
      },
    );
  }

  /// Forgets the cached token, forcing the next [fetch] to mint a new one.
  void invalidate() => _cached = null;
}
