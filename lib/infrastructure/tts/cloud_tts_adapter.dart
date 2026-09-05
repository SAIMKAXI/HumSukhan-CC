import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:humsukhan/core/failure/failure.dart';
import 'package:humsukhan/core/logging/app_logger.dart';
import 'package:humsukhan/core/result/result.dart';
import 'package:humsukhan/domain/speech/speech_failure.dart';
import 'package:humsukhan/domain/speech/tts_port.dart';
import 'package:humsukhan/domain/speech/utterance.dart';
import 'package:humsukhan/infrastructure/backend/backend_gateway.dart';

/// Synthesis through an Edge Function, for devices with no voice installed.
///
/// The provider credential stays server-side; this receives audio bytes.
final class CloudTtsAdapter implements TtsPort {
  /// Creates a cloud adapter.
  CloudTtsAdapter({
    required BackendGateway gateway,
    required String functionName,
    AudioPlayer? player,
    AppLogger logger = const SilentLogger(),
  }) : _gateway = gateway,
       _functionName = functionName,
       _player = player ?? AudioPlayer(),
       _logger = logger;

  final BackendGateway _gateway;
  final String _functionName;
  final AudioPlayer _player;
  final AppLogger _logger;

  final StreamController<TtsActivity> _activity =
      StreamController<TtsActivity>.broadcast();

  bool _disposed = false;

  @override
  Stream<TtsActivity> get activity => _activity.stream;

  @override
  Future<Result<Unit, TtsFailure>> speak(Utterance utterance) async {
    if (_disposed) {
      return const Err<Unit, TtsFailure>(
        TtsFailure(FailureCode.cancelled, isRecoverable: false),
      );
    }
    if (utterance.isEmpty) {
      return const Err<Unit, TtsFailure>(TtsFailure(FailureCode.invalidInput));
    }

    _push(TtsActivity.preparing);
    final Result<Map<String, Object?>, BackendFailure> response = await _gateway
        .invoke(
          _functionName,
          body: <String, Object?>{
            'text': utterance.text,
            'language': utterance.language.preferredLocale,
          },
        );

    if (_disposed) return const Ok<Unit, TtsFailure>(unit);

    if (response case Err<Map<String, Object?>, BackendFailure>(
      :final BackendFailure error,
    )) {
      _push(TtsActivity.idle);
      return Err<Unit, TtsFailure>(
        TtsFailure(
          error.code == FailureCode.network
              ? FailureCode.ttsFailed
              : error.code,
          detail: error.detail,
        ),
      );
    }

    final Object? encoded =
        (response as Ok<Map<String, Object?>, BackendFailure>).value['audio'];
    if (encoded is! String || encoded.isEmpty) {
      _push(TtsActivity.idle);
      return const Err<Unit, TtsFailure>(
        TtsFailure(FailureCode.ttsFailed, detail: 'no audio returned'),
      );
    }

    try {
      final Uint8List bytes = base64Decode(encoded);
      _push(TtsActivity.speaking);
      await _player.play(BytesSource(bytes));
      await _player.onPlayerComplete.first.timeout(
        const Duration(minutes: 2),
        onTimeout: () => PlayerState.completed,
      );
      if (!_disposed) _push(TtsActivity.idle);
      return const Ok<Unit, TtsFailure>(unit);
    } on Object catch (error, stackTrace) {
      _logger.log(
        LogLevel.error,
        'cloud-tts',
        'playback failed',
        error: error,
        stackTrace: stackTrace,
      );
      _push(TtsActivity.idle);
      return Err<Unit, TtsFailure>(
        TtsFailure(FailureCode.ttsFailed, detail: '$error'),
      );
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _player.stop();
    } on Object catch (error) {
      _logger.log(LogLevel.debug, 'cloud-tts', 'stop raised', error: error);
    }
    _push(TtsActivity.idle);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _player.dispose();
    await _activity.close();
  }

  void _push(TtsActivity value) {
    if (_disposed || _activity.isClosed) return;
    _activity.add(value);
  }
}
