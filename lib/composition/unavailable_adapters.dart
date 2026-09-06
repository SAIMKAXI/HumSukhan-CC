import 'dart:async';

import 'package:humsukhan/core/failure/failure.dart';
import 'package:humsukhan/core/result/result.dart';
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
