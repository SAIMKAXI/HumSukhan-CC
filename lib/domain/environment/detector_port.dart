import 'package:humsukhan/core/failure/failure.dart';
import 'package:humsukhan/core/result/result.dart';
import 'package:humsukhan/domain/environment/detection_policy.dart';

/// A detector failure.
final class DetectorFailure extends Failure {
  /// Creates a detector failure for [code].
  const DetectorFailure(
    FailureCode code, {
    super.detail,
    super.isRecoverable = true,
  }) : super(code: code);
}

/// On-device audio tagging.
///
/// Audio never leaves the device: implementations classify locally and expose
/// only observations.
abstract interface class SoundDetectorPort {
  /// Classifier outputs, one per analysis window.
  ///
  /// Like the recognition stream, this one must announce its own end through
  /// [failures] — a monitor that dies silently is a safety feature that fails
  /// closed and quiet.
  Stream<SoundObservation> get observations;

  /// Failures that ended detection.
  Stream<DetectorFailure> get failures;

  /// Starts listening. Returns [Err] when it could not start at all.
  Future<Result<Unit, DetectorFailure>> start();

  /// Stops listening.
  Future<void> stop();

  /// Releases the model and the microphone.
  Future<void> dispose();
}
