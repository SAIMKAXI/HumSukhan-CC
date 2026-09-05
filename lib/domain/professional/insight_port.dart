import 'package:humsukhan/core/failure/failure.dart';
import 'package:humsukhan/core/result/result.dart';
import 'package:humsukhan/domain/professional/insight.dart';
import 'package:humsukhan/domain/speech/language_tag.dart';

/// A summarisation failure.
final class InsightFailure extends Failure {
  /// Creates an insight failure for [code].
  const InsightFailure(
    FailureCode code, {
    super.detail,
    super.isRecoverable = true,
  }) : super(code: code);
}

/// Turns a complete transcript into a summary.
///
/// The provider credential lives server-side; the client calls an Edge Function
/// and never holds a third-party key.
abstract interface class InsightPort {
  /// Summarises [transcript], writing the result in [language].
  Future<Result<Insight, InsightFailure>> summarise({
    required String transcript,
    required LanguageTag language,
  });
}
