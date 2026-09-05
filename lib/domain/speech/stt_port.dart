import 'package:humsukhan/core/result/result.dart';
import 'package:humsukhan/domain/speech/language_tag.dart';
import 'package:humsukhan/domain/speech/speech_failure.dart';
import 'package:humsukhan/domain/speech/stt_event.dart';

/// How much a recogniser should do for the caller.
enum SttProfile {
  /// Short turns with fast partials — Everyday mode.
  conversation,

  /// Long-running capture that must survive transport drops — Professional
  /// mode. Interim results are still emitted; the caller decides to hide them.
  dictation,
}

/// What to recognise, and how.
final class SttRequest {
  /// Creates a recognition request.
  const SttRequest({
    required this.language,
    this.profile = SttProfile.conversation,
    this.interimResults = true,
    this.punctuate = true,
  });

  /// The language to recognise.
  final LanguageTag language;

  /// The behaviour profile.
  final SttProfile profile;

  /// Whether partial results are wanted.
  final bool interimResults;

  /// Whether the service should punctuate.
  final bool punctuate;

  @override
  bool operator ==(Object other) =>
      other is SttRequest &&
      other.language == language &&
      other.profile == profile &&
      other.interimResults == interimResults &&
      other.punctuate == punctuate;

  @override
  int get hashCode =>
      Object.hash(language, profile, interimResults, punctuate);
}

/// Speech recognition, narrowed to what the application actually needs.
///
/// Implementations own a transport; the application owns the session state.
abstract interface class SttPort {
  /// Every recognition event, including the terminal ones.
  ///
  /// The stream must emit [SttEnded] or [SttFailed] before it closes. A silent
  /// close is the defect this port exists to prevent.
  Stream<SttEvent> get events;

  /// Begins recognition.
  ///
  /// Returns [Err] when recognition could not be started at all; failures that
  /// happen later arrive on [events] as [SttFailed].
  Future<Result<Unit, SttFailure>> start(SttRequest request);

  /// Stops recognition. Safe to call when not started.
  Future<void> stop();

  /// Releases the transport. The port is unusable afterwards.
  Future<void> dispose();
}
