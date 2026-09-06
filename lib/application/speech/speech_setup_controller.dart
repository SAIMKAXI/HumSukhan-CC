import 'dart:async';

import 'package:humsukhan/core/failure/failure.dart';
import 'package:humsukhan/core/logging/app_logger.dart';
import 'package:humsukhan/domain/speech/capability.dart';
import 'package:humsukhan/domain/speech/language_tag.dart';
import 'package:humsukhan/domain/speech/speech_install_port.dart';

/// What the speech-setup flow is doing, and what it is for.
///
/// One object rather than a handful of booleans: the screen renders exactly one
/// of these, so there is no combination of flags that can describe a state the
/// product never intended.
final class SpeechSetupState {
  /// Creates a state.
  const SpeechSetupState({
    this.facility,
    this.language,
    this.progress,
    this.canInstall = false,
    this.isChecking = false,
  });

  /// Nothing is being set up.
  static const SpeechSetupState idle = SpeechSetupState();

  /// Which half of the stack is being installed, when one is.
  final SpeechFacility? facility;

  /// Which language is being installed.
  final LanguageTag? language;

  /// How far the install has got. `null` when no install is running.
  final InstallProgress? progress;

  /// Whether this device offers a guided install at all.
  ///
  /// When false the UI explains rather than offering a button that does
  /// nothing — an inert control is worse than an honest sentence.
  final bool canInstall;

  /// Whether a capability probe is in flight.
  final bool isChecking;

  /// Whether the setup sheet should be on screen.
  bool get isActive => progress != null;

  /// Whether the flow is waiting for the user to come back from a system
  /// screen, and so must re-check on resume.
  bool get awaitsResume => progress is InstallHandedOff;

  /// Whether the install finished successfully.
  bool get isCompleted => progress is InstallCompleted;

  /// The failure to render, when the flow failed.
  InstallFailed? get failure {
    final InstallProgress? current = progress;
    return current is InstallFailed ? current : null;
  }

  /// Copies with the given changes.
  ///
  /// [clearProgress] exists so a finished flow can drop its bar entirely; a
  /// merge-only copy would let a stale percentage outlive the state it belongs
  /// to.
  SpeechSetupState copyWith({
    SpeechFacility? facility,
    LanguageTag? language,
    InstallProgress? progress,
    bool? canInstall,
    bool? isChecking,
    bool clearProgress = false,
  }) => SpeechSetupState(
    facility: facility ?? this.facility,
    language: language ?? this.language,
    progress: clearProgress ? null : (progress ?? this.progress),
    canInstall: canInstall ?? this.canInstall,
    isChecking: isChecking ?? this.isChecking,
  );

  @override
  bool operator ==(Object other) =>
      other is SpeechSetupState &&
      other.facility == facility &&
      other.language == language &&
      other.progress == progress &&
      other.canInstall == canInstall &&
      other.isChecking == isChecking;

  @override
  int get hashCode =>
      Object.hash(facility, language, progress, canInstall, isChecking);
}

/// Runs the "this language needs a download" conversation, start to finish.
///
/// The product rule, in one place: a user missing a language pack sees a plain
/// sentence and one button, the device does the work, and the app returns them
/// to whatever they were trying to do. The action they were attempting is held
/// in [_pending] and replayed on success, so the answer to "what happens after
/// it installs?" is never "go and find the button again".
///
/// Every feature calls [ensure] instead of testing capability itself, which is
/// what stops one screen from quietly forgetting the check.
final class SpeechSetupController {
  /// Creates a controller.
  SpeechSetupController({
    required SpeechCapabilityPort capability,
    required SpeechInstallPort installer,
    AppLogger logger = const SilentLogger(),
  }) : _capability = capability,
       _installer = installer,
       _logger = logger;

  final SpeechCapabilityPort _capability;
  final SpeechInstallPort _installer;
  final AppLogger _logger;

  final StreamController<SpeechSetupState> _states =
      StreamController<SpeechSetupState>.broadcast();

  SpeechSetupState _state = SpeechSetupState.idle;
  StreamSubscription<InstallProgress>? _install;
  Future<void> Function()? _pending;
  bool _disposed = false;

  /// The flow's state right now.
  SpeechSetupState get state => _state;

  /// Every change to [state].
  Stream<SpeechSetupState> get states => _states.stream;

  /// Checks [facility] for [language] and, when it is missing, opens the guided
  /// flow instead of running [action].
  ///
  /// Returns true when [action] ran. On false the flow is on screen and
  /// [action] has been held for replay.
  Future<bool> ensure({
    required SpeechFacility facility,
    required LanguageTag language,
    Future<void> Function()? action,
  }) async {
    if (_disposed) return false;
    _emit(
      _state.copyWith(
        facility: facility,
        language: language,
        isChecking: true,
        clearProgress: true,
      ),
    );

    final Capability answer = await _probe(facility, language);
    if (_disposed) return false;
    _emit(_state.copyWith(isChecking: false));

    // `Unknown` means the engine could not be asked, not that it lacks the
    // language. Blocking on a question we failed to ask is the worse of the two
    // mistakes — it stops working hardware — so the attempt goes ahead.
    if (answer is CapabilityAvailable || answer is CapabilityUnknown) {
      await action?.call();
      return true;
    }

    _pending = action;
    final bool guided = await _installer.canInstall(facility);
    if (_disposed) return false;

    _emit(
      _state.copyWith(
        canInstall: guided,
        progress: guided
            ? const InstallStarting()
            // Nothing to offer. Say what is missing and stop, rather than
            // opening a screen whose only button does nothing.
            : InstallFailed(_missingCode(facility), canRetry: false),
      ),
    );
    return false;
  }

  /// Starts the download the user just agreed to.
  Future<void> accept() async {
    final SpeechFacility? facility = _state.facility;
    final LanguageTag? language = _state.language;
    if (_disposed || facility == null || language == null) return;

    await _install?.cancel();
    _emit(_state.copyWith(progress: const InstallStarting()));

    _install = _installer
        .install(facility, language)
        .listen(
          (InstallProgress progress) {
            if (_disposed) return;
            _emit(_state.copyWith(progress: progress));
            if (progress is InstallCompleted) unawaited(_resume());
          },
          onError: (Object error, StackTrace stackTrace) {
            _logger.log(
              LogLevel.error,
              'setup',
              'install stream failed',
              error: error,
              stackTrace: stackTrace,
            );
            if (!_disposed) {
              _emit(
                _state.copyWith(
                  progress: const InstallFailed(FailureCode.unknown),
                ),
              );
            }
          },
          // A stream that ends without a terminal state would leave a spinner
          // on screen for ever. It is not allowed to end quietly.
          onDone: () {
            if (_disposed) return;
            if (_state.progress?.isTerminal ?? true) return;
            if (_state.awaitsResume) return;
            _emit(
              _state.copyWith(
                progress: const InstallFailed(FailureCode.unknown),
              ),
            );
          },
        );
  }

  /// Re-checks after the user comes back from a system installer.
  ///
  /// Called on app resume. This is what closes the loop for synthesis, where
  /// the platform reports nothing at all.
  Future<void> onResumed() async {
    if (_disposed) return;
    // Always invalidate: a device that gained a voice while the app was in the
    // background must be able to discover it, flow or no flow.
    await _capability.invalidate();
    if (!_state.awaitsResume) return;

    final SpeechFacility? facility = _state.facility;
    final LanguageTag? language = _state.language;
    if (facility == null || language == null) return;

    _emit(_state.copyWith(progress: const InstallVerifying()));
    final Capability answer = await _probe(facility, language);
    if (_disposed) return;

    if (answer.isAvailable) {
      _emit(_state.copyWith(progress: const InstallCompleted()));
      await _resume();
      return;
    }
    // They came back without installing it. Not an error — an unfinished job,
    // offered again rather than complained about.
    _emit(_state.copyWith(progress: InstallFailed(_missingCode(facility))));
  }

  /// Closes the flow and abandons the held action.
  void dismiss() {
    unawaited(_install?.cancel());
    _install = null;
    _pending = null;
    _emit(SpeechSetupState.idle);
  }

  /// Releases the controller.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _install?.cancel();
    _install = null;
    _pending = null;
    await _states.close();
  }

  /// Runs the held action, then closes the flow.
  ///
  /// The action goes first and the subscription is torn down behind it: making
  /// the user's own work queue behind a stream cancellation adds a visible
  /// delay to the thing they actually asked for. A late duplicate event is
  /// harmless — [_pending] is already cleared, so nothing runs twice.
  Future<void> _resume() async {
    final Future<void> Function()? action = _pending;
    _pending = null;
    final StreamSubscription<InstallProgress>? finished = _install;
    _install = null;
    unawaited(finished?.cancel());
    if (action != null) await action();
    if (!_disposed) _emit(SpeechSetupState.idle);
  }

  Future<Capability> _probe(SpeechFacility facility, LanguageTag language) =>
      switch (facility) {
        SpeechFacility.recognition => _capability.stt(language),
        SpeechFacility.synthesis => _capability.tts(language),
      };

  static FailureCode _missingCode(SpeechFacility facility) =>
      switch (facility) {
        SpeechFacility.recognition => FailureCode.sttLanguageUnsupported,
        SpeechFacility.synthesis => FailureCode.ttsVoiceMissing,
      };

  void _emit(SpeechSetupState next) {
    _state = next;
    if (!_states.isClosed) _states.add(next);
  }
}
