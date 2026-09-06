import 'dart:async';

import 'package:humsukhan/core/logging/app_logger.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// One result from the platform recogniser.
final class RecognisedSpeech {
  /// Creates a result.
  const RecognisedSpeech({
    required this.text,
    required this.isFinal,
    this.confidence,
  });

  /// What was heard.
  final String text;

  /// Whether the engine considers this settled.
  final bool isFinal;

  /// Engine confidence in `0..1`, when it reports a usable one.
  final double? confidence;
}

/// A problem reported by the platform recogniser.
final class RecogniserError {
  /// Creates an error.
  const RecogniserError(this.code, {required this.permanent});

  /// The platform's own code, for example `error_no_match`. Never displayed.
  final String code;

  /// Whether the engine says recognition cannot continue.
  final bool permanent;

  /// Whether this is the ordinary "heard nothing" outcome of a silent gap.
  ///
  /// Android reports these constantly during natural pauses. Treating them as
  /// failures is what makes a recogniser look broken when it is merely waiting.
  bool get isSilence =>
      code == 'error_speech_timeout' ||
      code == 'error_no_match' ||
      code == 'error_retry';

  @override
  String toString() => 'RecogniserError($code, permanent: $permanent)';
}

/// The narrow surface of the device recogniser that HumSukhan needs.
///
/// A seam, not an abstraction for its own sake: it is what lets the restart and
/// failure logic in [NativeSttAdapter] be tested with no device, no microphone
/// and no network, which is the only way that logic ever gets exercised.
abstract interface class PlatformRecogniser {
  /// Prepares the engine. Returns false when there is no recogniser at all.
  Future<bool> initialise({
    required void Function(RecogniserError error) onError,
    required void Function(String status) onStatus,
  });

  /// Whether the engine is present on this device.
  Future<bool> isAvailable();

  /// The locale identifiers the engine offers, lower-cased with `-` separators.
  Future<Set<String>> localeIds();

  /// Starts one listening segment.
  ///
  /// Platform recognisers end a segment on silence; the caller restarts. When
  /// [onDevice] is set the engine must not use the network, and the call fails
  /// if it cannot honour that.
  Future<void> listen({
    required String localeId,
    required bool partialResults,
    required bool onDevice,
    required bool punctuate,
    required bool dictation,
    required Duration pauseFor,
    required Duration listenFor,
    required void Function(RecognisedSpeech result) onResult,
  });

  /// Ends the current segment, letting a final result arrive.
  Future<void> stop();

  /// Ends the current segment and discards any pending result.
  Future<void> cancel();
}

/// [PlatformRecogniser] over `speech_to_text`, which is Android's
/// `SpeechRecognizer` and iOS's `SFSpeechRecognizer`.
final class SpeechToTextRecogniser implements PlatformRecogniser {
  /// Creates a recogniser.
  SpeechToTextRecogniser({
    SpeechToText? engine,
    AppLogger logger = const SilentLogger(),
  }) : _speech = engine ?? SpeechToText(),
       _logger = logger;

  final SpeechToText _speech;
  final AppLogger _logger;
  bool _initialised = false;

  @override
  Future<bool> initialise({
    required void Function(RecogniserError error) onError,
    required void Function(String status) onStatus,
  }) async {
    if (_initialised) return true;
    try {
      _initialised = await _speech.initialize(
        onError: (SpeechRecognitionError error) => onError(
          RecogniserError(error.errorMsg, permanent: error.permanent),
        ),
        onStatus: onStatus,
        // The plugin's default final-result timeout is deliberately left
        // alone: it is what makes a trailing partial settle into a final when
        // the engine goes quiet, and setting it near zero disables that guard.
      );
      return _initialised;
    } on Object catch (error, stackTrace) {
      _logger.log(
        LogLevel.error,
        'stt',
        'recogniser initialise failed',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  @override
  Future<bool> isAvailable() async {
    if (_initialised) return true;
    try {
      return await _speech.initialize();
    } on Object catch (error) {
      _logger.log(LogLevel.debug, 'stt', 'no recogniser', error: error);
      return false;
    }
  }

  @override
  Future<Set<String>> localeIds() async {
    try {
      final List<LocaleName> locales = await _speech.locales();
      return locales
          .map((LocaleName l) => l.localeId.toLowerCase().replaceAll('_', '-'))
          .toSet();
    } on Object catch (error) {
      _logger.log(
        LogLevel.warning,
        'stt',
        'could not list recogniser locales',
        error: error,
      );
      return <String>{};
    }
  }

  @override
  Future<void> listen({
    required String localeId,
    required bool partialResults,
    required bool onDevice,
    required bool punctuate,
    required bool dictation,
    required Duration pauseFor,
    required Duration listenFor,
    required void Function(RecognisedSpeech result) onResult,
  }) async {
    await _speech.listen(
      onResult: (SpeechRecognitionResult result) => onResult(
        RecognisedSpeech(
          text: result.recognizedWords,
          isFinal: result.finalResult,
          // The plugin reports 0 when it has no opinion. Passing that on as a
          // real confidence would let the UI render certainty it never had.
          confidence: result.confidence > 0 ? result.confidence : null,
        ),
      ),
      listenOptions: SpeechListenOptions(
        localeId: localeId,
        partialResults: partialResults,
        onDevice: onDevice,
        autoPunctuation: punctuate,
        listenMode: dictation ? ListenMode.dictation : ListenMode.confirmation,
        pauseFor: pauseFor,
        listenFor: listenFor,
        // `cancelOnError` and `enableHapticFeedback` are both left at their
        // false defaults on purpose: cancelling inside the plugin would end the
        // session behind the adapter's back, and a buzz on every segment
        // restart would be constant during normal speech.
      ),
    );
  }

  @override
  Future<void> stop() async {
    try {
      await _speech.stop();
    } on Object catch (error) {
      _logger.log(LogLevel.debug, 'stt', 'stop raised', error: error);
    }
  }

  @override
  Future<void> cancel() async {
    try {
      await _speech.cancel();
    } on Object catch (error) {
      _logger.log(LogLevel.debug, 'stt', 'cancel raised', error: error);
    }
  }
}
