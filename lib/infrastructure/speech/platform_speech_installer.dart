import 'dart:async';

import 'package:flutter/services.dart';
import 'package:humsukhan/core/failure/failure.dart';
import 'package:humsukhan/core/logging/app_logger.dart';
import 'package:humsukhan/domain/speech/capability.dart';
import 'package:humsukhan/domain/speech/language_tag.dart';
import 'package:humsukhan/domain/speech/speech_install_port.dart';

/// [SpeechInstallPort] over the platform channel `MainActivity` installs.
///
/// The Dart half deliberately trusts nothing the platform claims about success.
/// Android reports a model "downloaded" before the recogniser will admit to
/// having it, and a TTS installer activity reports nothing at all — so every
/// path here ends by asking the engine itself whether the language now works,
/// and only that answer produces [InstallCompleted]. A flow that declared
/// victory on the platform's word would strand the user right back at the
/// feature that still does not work.
final class PlatformSpeechInstaller implements SpeechInstallPort {
  /// Creates an installer.
  PlatformSpeechInstaller({
    required SpeechCapabilityPort capability,
    MethodChannel? methods,
    EventChannel? events,
    AppLogger logger = const SilentLogger(),
    this.downloadTimeout = const Duration(minutes: 5),
    this.pollInterval = const Duration(seconds: 2),
    this.settleTimeout = const Duration(seconds: 20),
  }) : _capability = capability,
       _methods = methods ?? const MethodChannel(methodChannelName),
       _events = events ?? const EventChannel(eventChannelName),
       _logger = logger;

  /// The method channel `MainActivity` registers.
  static const String methodChannelName = 'pk.humsukhan/speech_install';

  /// The event channel carrying download progress.
  static const String eventChannelName = 'pk.humsukhan/speech_install_events';

  final SpeechCapabilityPort _capability;
  final MethodChannel _methods;
  final EventChannel _events;
  final AppLogger _logger;

  /// How long a download may run before the flow reports a timeout.
  final Duration downloadTimeout;

  /// How often the engine is re-asked while waiting.
  final Duration pollInterval;

  /// How long to keep re-asking after the platform claims success.
  final Duration settleTimeout;

  @override
  Future<bool> canInstall(SpeechFacility facility) async {
    try {
      final bool? answer = await _methods.invokeMethod<bool>(
        'canInstall',
        <String, Object?>{'facility': facility.key},
      );
      return answer ?? false;
    } on Object catch (error) {
      // A platform with no channel — iOS, or a widget test — simply has no
      // guided install. Reporting that is correct; throwing would break the
      // caller and hide a perfectly ordinary situation.
      _logger.log(
        LogLevel.debug,
        'install',
        'canInstall unavailable',
        error: error,
      );
      return false;
    }
  }

  @override
  Stream<InstallProgress> install(
    SpeechFacility facility,
    LanguageTag language,
  ) {
    final StreamController<InstallProgress> output =
        StreamController<InstallProgress>();
    unawaited(_run(facility, language, output));
    return output.stream;
  }

  Future<void> _run(
    SpeechFacility facility,
    LanguageTag language,
    StreamController<InstallProgress> output,
  ) async {
    void emit(InstallProgress progress) {
      if (!output.isClosed) output.add(progress);
    }

    try {
      emit(const InstallStarting());

      // Asking again costs one call and prevents the worst outcome this flow
      // has: sending someone to install what they already have.
      if (await _isReady(facility, language)) {
        emit(const InstallCompleted());
        return;
      }

      switch (facility) {
        case SpeechFacility.recognition:
          await _installRecognition(language, emit);
        case SpeechFacility.synthesis:
          await _installSynthesis(language, emit);
      }
    } on Object catch (error, stackTrace) {
      _logger.log(
        LogLevel.error,
        'install',
        'install flow raised',
        error: error,
        stackTrace: stackTrace,
      );
      emit(const InstallFailed(FailureCode.unknown));
    } finally {
      await output.close();
    }
  }

  /// Recognition on Android 13+: in the app, with real progress on 14+.
  Future<void> _installRecognition(
    LanguageTag language,
    void Function(InstallProgress) emit,
  ) async {
    final Completer<InstallProgress> settled = Completer<InstallProgress>();
    bool announced = false;

    // Subscribed before the trigger fires, so a fast download cannot complete
    // in the gap between asking for it and listening for it.
    final StreamSubscription<Object?> updates = _events
        .receiveBroadcastStream()
        .listen(
          (Object? event) {
            if (event is! Map<Object?, Object?>) return;
            switch ('${event['state']}') {
              case 'downloading':
                final Object? value = event['progress'];
                announced = true;
                emit(
                  InstallDownloading(value is num ? value.toDouble() : null),
                );
              case 'scheduled':
                // Accepted, running later or silently. An indeterminate bar is
                // honest here; a percentage would be invented.
                if (!announced) {
                  announced = true;
                  emit(const InstallDownloading(null));
                }
              case 'completed':
                if (!settled.isCompleted) {
                  settled.complete(const InstallVerifying());
                }
              case 'failed':
                if (!settled.isCompleted) {
                  settled.complete(
                    const InstallFailed(FailureCode.modelDownloadFailed),
                  );
                }
            }
          },
          onError: (Object error) {
            _logger.log(
              LogLevel.warning,
              'install',
              'progress stream error',
              error: error,
            );
          },
        );

    // The poll below outlives the race it is entered into unless something
    // stops it: losing a `Future.any` does not cancel the loser, so a loop left
    // running would re-probe the engine every couple of seconds for the life of
    // the app, invalidating the capability cache each time. This ends it.
    bool finished = false;

    try {
      try {
        await _methods.invokeMethod<String>('installStt', <String, Object?>{
          'locale': language.preferredLocale,
        });
      } on PlatformException catch (error) {
        final bool unsupported = error.code == 'unsupported';
        emit(
          InstallFailed(
            unsupported
                ? FailureCode.sttLanguageUnsupported
                : FailureCode.modelDownloadFailed,
            canRetry: !unsupported,
          ),
        );
        return;
      }

      // Two ways to learn the download finished, whichever comes first: the
      // platform saying so, or the engine simply having the language. Android
      // 13 reports nothing after accepting the request, so without the poll
      // this flow would time out on a download that actually succeeded.
      final InstallProgress outcome =
          await Future.any(<Future<InstallProgress>>[
            settled.future,
            _pollUntilReady(
              SpeechFacility.recognition,
              language,
              () => finished,
            ),
          ]).timeout(
            downloadTimeout,
            onTimeout: () => const InstallFailed(FailureCode.timeout),
          );

      if (outcome is InstallVerifying) {
        emit(const InstallVerifying());
        // The platform's "done" is a claim; the recogniser's own locale list is
        // the fact, and only the fact ends this successfully.
        emit(
          await _settle(SpeechFacility.recognition, language)
              ? const InstallCompleted()
              : const InstallFailed(FailureCode.sttLanguageUnsupported),
        );
        return;
      }
      emit(outcome);
    } finally {
      finished = true;
      await updates.cancel();
    }
  }

  /// Synthesis: the engine's own installer, then verification on return.
  Future<void> _installSynthesis(
    LanguageTag language,
    void Function(InstallProgress) emit,
  ) async {
    try {
      await _methods.invokeMethod<String>('installTts', <String, Object?>{
        'locale': language.preferredLocale,
      });
    } on PlatformException catch (error) {
      final bool unsupported = error.code == 'unsupported';
      emit(InstallFailed(FailureCode.ttsVoiceMissing, canRetry: !unsupported));
      return;
    }

    // The system installer is now in front of the user. The flow stops here
    // rather than burning a timer while somebody reads an OS screen; the
    // controller resumes it when the app comes back.
    emit(const InstallHandedOff());
  }

  /// Completes with [InstallCompleted] once the engine has the language.
  ///
  /// Stops when [abandoned] goes true, which is how the caller ends it after
  /// the race it was entered into has been won by something else.
  Future<InstallProgress> _pollUntilReady(
    SpeechFacility facility,
    LanguageTag language,
    bool Function() abandoned,
  ) async {
    while (!abandoned()) {
      await Future<void>.delayed(pollInterval);
      if (abandoned()) break;
      if (await _isReady(facility, language)) return const InstallCompleted();
    }
    // Only reached by the loser of the race, whose value `Future.any` discards.
    return const InstallFailed(FailureCode.cancelled, canRetry: false);
  }

  /// Re-asks the engine until it agrees, or [settleTimeout] expires.
  Future<bool> _settle(SpeechFacility facility, LanguageTag language) async {
    final Stopwatch elapsed = Stopwatch()..start();
    while (elapsed.elapsed < settleTimeout) {
      if (await _isReady(facility, language)) return true;
      await Future<void>.delayed(pollInterval);
    }
    return false;
  }

  Future<bool> _isReady(SpeechFacility facility, LanguageTag language) async {
    // Without invalidating first, the cached "no" from before the install would
    // answer forever and the flow could never succeed.
    await _capability.invalidate();
    final Capability answer = switch (facility) {
      SpeechFacility.recognition => await _capability.stt(language),
      SpeechFacility.synthesis => await _capability.tts(language),
    };
    return answer.isAvailable;
  }
}
