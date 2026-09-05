import 'package:humsukhan/core/failure/failure.dart';
import 'package:humsukhan/core/result/result.dart';
import 'package:humsukhan/domain/professional/insight.dart';
import 'package:humsukhan/domain/professional/insight_port.dart';
import 'package:humsukhan/domain/speech/language_tag.dart';
import 'package:humsukhan/infrastructure/backend/backend_gateway.dart';

/// Summarises a transcript through an Edge Function.
///
/// The model provider's key stays on the server. The client sends a transcript
/// and receives structured JSON.
final class EdgeInsightAdapter implements InsightPort {
  /// Creates an adapter.
  EdgeInsightAdapter({
    required BackendGateway gateway,
    required String functionName,
    DateTime Function()? now,
  }) : _gateway = gateway,
       _functionName = functionName,
       _now = now ?? DateTime.now;

  final BackendGateway _gateway;
  final String _functionName;
  final DateTime Function() _now;

  @override
  Future<Result<Insight, InsightFailure>> summarise({
    required String transcript,
    required LanguageTag language,
  }) async {
    if (transcript.trim().isEmpty) {
      return const Err<Insight, InsightFailure>(
        InsightFailure(
          FailureCode.insightTranscriptEmpty,
          isRecoverable: false,
        ),
      );
    }

    final Result<Map<String, Object?>, BackendFailure> response = await _gateway
        .invoke(
          _functionName,
          body: <String, Object?>{
            'transcript': transcript,
            'language': language.code,
          },
        );

    return response.fold(
      (Map<String, Object?> body) {
        final Insight insight = _parse(body);
        if (insight.isEmpty) {
          return const Err<Insight, InsightFailure>(
            InsightFailure(
              FailureCode.insightGenerationFailed,
              detail: 'the summariser returned nothing usable',
            ),
          );
        }
        return Ok<Insight, InsightFailure>(insight);
      },
      (BackendFailure failure) => Err<Insight, InsightFailure>(
        InsightFailure(
          failure.code == FailureCode.network
              ? FailureCode.insightGenerationFailed
              : failure.code,
          detail: failure.detail,
        ),
      ),
    );
  }

  Insight _parse(Map<String, Object?> body) => Insight(
    summary: body['summary'] as String? ?? '',
    generatedAt: _now(),
    keyPoints: _strings(body['key_points']),
    people: _strings(body['people']),
    actionItems: body['action_items'] is List<Object?>
        ? (body['action_items']! as List<Object?>)
              .whereType<Map<String, Object?>>()
              .map(
                (Map<String, Object?> item) => ActionItem(
                  description: item['description'] as String? ?? '',
                  owner: item['owner'] as String?,
                  deadline: item['deadline'] as String?,
                ),
              )
              .where((ActionItem item) => item.description.trim().isNotEmpty)
              .toList(growable: false)
        : const <ActionItem>[],
  );

  List<String> _strings(Object? value) => value is List<Object?>
      ? value
            .whereType<String>()
            .where((String s) => s.trim().isNotEmpty)
            .toList(growable: false)
      : const <String>[];
}
