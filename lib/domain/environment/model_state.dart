import 'package:humsukhan/core/failure/failure.dart';

/// A model-lifecycle failure.
final class ModelFailure extends Failure {
  /// Creates a model failure for [code].
  const ModelFailure(
    FailureCode code, {
    super.detail,
    super.isRecoverable = true,
  }) : super(code: code);
}

/// Where the on-device sound model is in its lifecycle.
///
/// "Ready" means *successfully loaded at least once*, not "the file exists" —
/// the existence-only check is what made a corrupt download a permanent trap
/// (B6).
sealed class ModelState {
  const ModelState();
}

/// Not installed.
final class ModelAbsent extends ModelState {
  /// Creates the absent state.
  const ModelAbsent();
}

/// Being fetched.
final class ModelDownloading extends ModelState {
  /// Creates a downloading state at [progress] in `0..1`, or `null` when the
  /// total size is unknown.
  const ModelDownloading(this.progress);

  /// Fraction complete, when known.
  final double? progress;
}

/// Downloaded, being checked against its expected size and checksum.
final class ModelVerifying extends ModelState {
  /// Creates the verifying state.
  const ModelVerifying();
}

/// Verified and loaded by the tagger.
final class ModelReady extends ModelState {
  /// Creates the ready state.
  const ModelReady(this.path);

  /// Where the loaded artefact is.
  final String path;
}

/// Unusable, with the reason and whether a retry is worthwhile.
final class ModelFailed extends ModelState {
  /// Creates the failed state.
  const ModelFailed(this.cause);

  /// Why it is unusable.
  final ModelFailure cause;
}

/// Owns download, verification, installation and healing of the sound model.
abstract interface class ModelRepositoryPort {
  /// The current state, and every change to it.
  Stream<ModelState> get state;

  /// The state right now.
  ModelState get current;

  /// Makes the model usable, healing anything unusable it finds.
  ///
  /// Never leaves a permanent failure: an artefact that will not load is
  /// quarantined and refetched.
  Future<ModelState> ensureReady();

  /// Discards the installed artefact so the next [ensureReady] refetches.
  Future<void> quarantine();
}
