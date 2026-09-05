import 'dart:async';
import 'dart:typed_data';

import 'package:humsukhan/core/failure/failure.dart';
import 'package:humsukhan/core/logging/app_logger.dart';
import 'package:humsukhan/core/result/result.dart';
import 'package:humsukhan/domain/speech/speech_failure.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

/// The one audio format everything downstream assumes: 16 kHz mono PCM16.
final class AudioFormat {
  const AudioFormat._();

  /// Samples per second.
  static const int sampleRate = 16000;

  /// Channel count.
  static const int channels = 1;

  /// Bytes per sample.
  static const int bytesPerSample = 2;
}

/// Opens the microphone and hands out raw PCM.
///
/// One implementation, one owner. Nothing else in the app touches `record`.
abstract interface class MicrophoneSource {
  /// Whether the microphone may be used, asking the user if necessary.
  Future<Result<Unit, AudioFailure>> ensurePermission();

  /// Starts capture and returns the PCM stream.
  Future<Result<Stream<Uint8List>, AudioFailure>> start();

  /// Stops capture.
  Future<void> stop();

  /// Releases the recorder.
  Future<void> dispose();
}

/// [MicrophoneSource] over the `record` plugin.
final class RecordMicrophoneSource implements MicrophoneSource {
  /// Creates a source.
  RecordMicrophoneSource({AppLogger logger = const SilentLogger()})
    : _logger = logger;

  final AppLogger _logger;
  final AudioRecorder _recorder = AudioRecorder();
  bool _running = false;

  @override
  Future<Result<Unit, AudioFailure>> ensurePermission() async {
    try {
      PermissionStatus status = await Permission.microphone.status;
      if (status.isGranted) return const Ok<Unit, AudioFailure>(unit);
      if (status.isPermanentlyDenied) {
        return const Err<Unit, AudioFailure>(
          AudioFailure(
            FailureCode.microphonePermissionPermanentlyDenied,
            isRecoverable: false,
          ),
        );
      }
      status = await Permission.microphone.request();
      if (status.isGranted) return const Ok<Unit, AudioFailure>(unit);
      return Err<Unit, AudioFailure>(
        AudioFailure(
          status.isPermanentlyDenied
              ? FailureCode.microphonePermissionPermanentlyDenied
              : FailureCode.microphonePermissionDenied,
          isRecoverable: !status.isPermanentlyDenied,
        ),
      );
    } on Object catch (error, stackTrace) {
      _logger.log(
        LogLevel.error,
        'microphone',
        'permission check failed',
        error: error,
        stackTrace: stackTrace,
      );
      return Err<Unit, AudioFailure>(
        AudioFailure(FailureCode.microphoneUnavailable, detail: '$error'),
      );
    }
  }

  @override
  Future<Result<Stream<Uint8List>, AudioFailure>> start() async {
    final Result<Unit, AudioFailure> permission = await ensurePermission();
    if (permission case Err<Unit, AudioFailure>(:final AudioFailure error)) {
      return Err<Stream<Uint8List>, AudioFailure>(error);
    }

    try {
      if (_running) await _recorder.stop();
      final Stream<Uint8List> stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: AudioFormat.sampleRate,
          numChannels: AudioFormat.channels,
          echoCancel: true,
          noiseSuppress: true,
        ),
      );
      _running = true;
      return Ok<Stream<Uint8List>, AudioFailure>(stream);
    } on Object catch (error, stackTrace) {
      _logger.log(
        LogLevel.error,
        'microphone',
        'could not open the microphone',
        error: error,
        stackTrace: stackTrace,
      );
      return Err<Stream<Uint8List>, AudioFailure>(
        AudioFailure(FailureCode.microphoneUnavailable, detail: '$error'),
      );
    }
  }

  @override
  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    try {
      await _recorder.stop();
    } on Object catch (error) {
      // Stopping a recorder that is already gone is not a user-visible problem,
      // but it is still recorded rather than swallowed.
      _logger.log(LogLevel.debug, 'microphone', 'stop raised', error: error);
    }
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _recorder.dispose();
  }
}
