import 'package:humsukhan/core/failure/failure.dart';

/// A recognition failure.
final class SttFailure extends Failure {
  /// Creates a recognition failure for [code].
  const SttFailure(FailureCode code, {super.detail, super.isRecoverable = true})
    : super(code: code);
}

/// A synthesis failure.
final class TtsFailure extends Failure {
  /// Creates a synthesis failure for [code].
  const TtsFailure(FailureCode code, {super.detail, super.isRecoverable = true})
    : super(code: code);
}

/// A microphone or audio-capture failure.
final class AudioFailure extends Failure {
  /// Creates an audio failure for [code].
  const AudioFailure(
    FailureCode code, {
    super.detail,
    super.isRecoverable = true,
  }) : super(code: code);
}
