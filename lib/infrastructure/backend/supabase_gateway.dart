import 'dart:async';

import 'package:humsukhan/core/failure/failure.dart';
import 'package:humsukhan/core/logging/app_logger.dart';
import 'package:humsukhan/core/result/result.dart';
import 'package:humsukhan/infrastructure/backend/backend_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Calls Supabase Edge Functions.
final class SupabaseGateway implements BackendGateway {
  /// Creates a gateway over [client].
  SupabaseGateway({
    required SupabaseClient client,
    AppLogger logger = const SilentLogger(),
    Duration timeout = const Duration(seconds: 30),
  }) : _client = client,
       _logger = logger,
       _timeout = timeout;

  final SupabaseClient _client;
  final AppLogger _logger;
  final Duration _timeout;

  @override
  Future<Result<Map<String, Object?>, BackendFailure>> invoke(
    String name, {
    Map<String, Object?> body = const <String, Object?>{},
  }) async {
    try {
      final FunctionResponse response = await _client.functions
          .invoke(name, body: body)
          .timeout(_timeout);

      if (response.status >= 400) {
        return Err<Map<String, Object?>, BackendFailure>(
          BackendFailure(
            response.status == 401 || response.status == 403
                ? FailureCode.authNoSession
                : FailureCode.network,
            detail: 'function $name returned ${response.status}',
          ),
        );
      }
      final Object? data = response.data;
      if (data is Map) {
        return Ok<Map<String, Object?>, BackendFailure>(
          data.map<String, Object?>(
            (Object? key, Object? value) =>
                MapEntry<String, Object?>(key.toString(), value),
          ),
        );
      }
      return Err<Map<String, Object?>, BackendFailure>(
        BackendFailure(
          FailureCode.unknown,
          detail: 'function $name returned ${data.runtimeType}',
        ),
      );
    } on TimeoutException catch (error) {
      _logger.log(LogLevel.warning, 'backend', '$name timed out', error: error);
      return const Err<Map<String, Object?>, BackendFailure>(
        BackendFailure(FailureCode.timeout),
      );
    } on FunctionException catch (error) {
      _logger.log(LogLevel.warning, 'backend', '$name failed', error: error);
      return Err<Map<String, Object?>, BackendFailure>(
        BackendFailure(
          error.status == 401 || error.status == 403
              ? FailureCode.authNoSession
              : FailureCode.network,
          detail: 'function $name: ${error.details ?? error.reasonPhrase}',
        ),
      );
    } on Object catch (error, stackTrace) {
      // Never swallowed: an unclassified backend error still reaches the user
      // as a failure with a remedy.
      _logger.log(
        LogLevel.error,
        'backend',
        '$name raised',
        error: error,
        stackTrace: stackTrace,
      );
      return Err<Map<String, Object?>, BackendFailure>(
        BackendFailure(FailureCode.network, detail: '$error'),
      );
    }
  }
}
