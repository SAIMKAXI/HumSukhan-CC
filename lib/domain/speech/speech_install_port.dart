import 'package:humsukhan/core/failure/failure.dart';
import 'package:humsukhan/domain/speech/language_tag.dart';

/// Which half of the speech stack a language pack is needed for.
enum SpeechFacility {
  /// Recognising speech — the caption side.
  recognition,

  /// Synthesising speech — the speak side.
  synthesis;

  /// A stable key for logs and cache entries.
  String get key => switch (this) {
    SpeechFacility.recognition => 'stt',
    SpeechFacility.synthesis => 'tts',
  };
}

/// Where a guided language install has got to.
///
/// The user sees this rendered as a sentence and a progress bar; nothing here
/// is ever surfaced as a code. Every path ends at [InstallCompleted] or
/// [InstallFailed] — a flow that can stall in the middle is the trap this
/// sealed set exists to prevent (instructions §2).
sealed class InstallProgress {
  const InstallProgress();

  /// Whether no further events will arrive.
  bool get isTerminal => this is InstallCompleted || this is InstallFailed;
}

/// The request is being made. Nothing has left the app yet.
final class InstallStarting extends InstallProgress {
  /// Creates the starting state.
  const InstallStarting();

  @override
  bool operator ==(Object other) => other is InstallStarting;

  @override
  int get hashCode => (InstallStarting).hashCode;

  @override
  String toString() => 'InstallStarting()';
}

/// The device is fetching the pack, and told us how far along it is.
final class InstallDownloading extends InstallProgress {
  /// Creates a downloading state at [progress] in `0..1`, or `null` when the
  /// platform reports no number — an indeterminate bar is honest, a fake
  /// percentage is not.
  const InstallDownloading(this.progress);

  /// Completion in `0..1`, or `null` when unknown.
  final double? progress;

  @override
  bool operator ==(Object other) =>
      other is InstallDownloading && other.progress == progress;

  @override
  int get hashCode => Object.hash(InstallDownloading, progress);

  @override
  String toString() => 'InstallDownloading($progress)';
}

/// The operating system took over — its own installer is now in front of the
/// user, and the app is waiting to be resumed.
///
/// This is the one case where the user leaves HumSukhan, and only because the
/// platform gives no in-process API for it. The app re-probes on resume and
/// continues by itself, so the user never has to find their way back to the
/// feature manually.
final class InstallHandedOff extends InstallProgress {
  /// Creates the handed-off state.
  const InstallHandedOff();

  @override
  bool operator ==(Object other) => other is InstallHandedOff;

  @override
  int get hashCode => (InstallHandedOff).hashCode;

  @override
  String toString() => 'InstallHandedOff()';
}

/// The pack is reported present; the app is re-asking the engine to be sure.
///
/// Never skipped: a platform that says "installed" and an engine that has the
/// voice are two different claims, and only the second one can speak.
final class InstallVerifying extends InstallProgress {
  /// Creates the verifying state.
  const InstallVerifying();

  @override
  bool operator ==(Object other) => other is InstallVerifying;

  @override
  int get hashCode => (InstallVerifying).hashCode;

  @override
  String toString() => 'InstallVerifying()';
}

/// The language is installed and was confirmed usable.
final class InstallCompleted extends InstallProgress {
  /// Creates the completed state.
  const InstallCompleted();

  @override
  bool operator ==(Object other) => other is InstallCompleted;

  @override
  int get hashCode => (InstallCompleted).hashCode;

  @override
  String toString() => 'InstallCompleted()';
}

/// The install did not happen, with a reason the user can act on.
final class InstallFailed extends InstallProgress {
  /// Creates a failure with [reason], and whether offering *Try again* is
  /// honest. Offering a retry that cannot succeed is its own defect.
  const InstallFailed(this.reason, {this.canRetry = true});

  /// Why it failed.
  final FailureCode reason;

  /// Whether retrying could plausibly work.
  final bool canRetry;

  @override
  bool operator ==(Object other) =>
      other is InstallFailed &&
      other.reason == reason &&
      other.canRetry == canRetry;

  @override
  int get hashCode => Object.hash(InstallFailed, reason, canRetry);

  @override
  String toString() => 'InstallFailed(${reason.name}, retry: $canRetry)';
}

/// Installs speech language packs using whatever the device itself provides.
///
/// The contract the product depends on: the user presses one button and the
/// device does the rest. An implementation may hand off to a system installer
/// ([InstallHandedOff]) but must never ask the user to go and find a setting —
/// that is the failure this port replaces.
abstract interface class SpeechInstallPort {
  /// Whether a guided install exists on this device for [facility].
  ///
  /// False means the flow must not be offered at all: a button that opens
  /// nothing is worse than an honest explanation.
  Future<bool> canInstall(SpeechFacility facility);

  /// Runs the install for [language], reporting progress until a terminal
  /// state. Never throws; transport problems arrive as [InstallFailed].
  Stream<InstallProgress> install(
    SpeechFacility facility,
    LanguageTag language,
  );
}
