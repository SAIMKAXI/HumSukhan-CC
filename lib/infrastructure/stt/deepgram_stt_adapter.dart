import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:humsukhan/core/failure/failure.dart';
import 'package:humsukhan/core/logging/app_logger.dart';
import 'package:humsukhan/core/result/result.dart';
import 'package:humsukhan/domain/speech/language_tag.dart';
import 'package:humsukhan/domain/speech/speech_failure.dart';
import 'package:humsukhan/domain/speech/stt_event.dart';
import 'package:humsukhan/domain/speech/stt_port.dart';
import 'package:humsukhan/infrastructure/audio/microphone_source.dart';
import 'package:humsukhan/infrastructure/stt/recognition_token.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Opens a recognition socket. Injected so the adapter is testable with a fake
/// transport rather than a real Deepgram connection.
typedef SocketFactory = Future<WebSocketChannel> Function(
  Uri url,
  String token,
);

/// Streams microphone audio to Deepgram and turns its messages into
/// [SttEvent]s.
///
/// Reconnects on transport loss, because a 30-minute lecture will lose its
/// socket at least once and losing the socket must not mean losing the session.
final class DeepgramSttAdapter implements SttPort {
  /// Creates an adapter.
  DeepgramSttAdapter({
    required MicrophoneSource microphone,
    required RecognitionTokenSource tokens,
    SocketFactory? socketFactory,
    AppLogger logger = const SilentLogger(),
    this.maxReconnectAttempts = 5,
    this.reconnectBackoff = const <Duration>[
      Duration(milliseconds: 400),
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 4),
      Duration(seconds: 8),
    ],
    String host = 'api.deepgram.com',
  }) : _microphone = microphone,
       _tokens = tokens,
       _logger = logger,
       _host = host,
       _socketFactory = socketFactory ?? _defaultSocketFactory;

  static Future<WebSocketChannel> _defaultSocketFactory(
    Uri url,
    String token,
  ) async {
    final WebSocketChannel channel = WebSocketChannel.connect(
      url,
      protocols: <String>['token', token],
    );
    await channel.ready;
    return channel;
  }

  final MicrophoneSource _microphone;
  final RecognitionTokenSource _tokens;
  final SocketFactory _socketFactory;
  final AppLogger _logger;
  final String _host;

  /// How many times a lost transport is retried before giving up.
  final int maxReconnectAttempts;

  /// The delay before each retry.
  final List<Duration> reconnectBackoff;

  final StreamController<SttEvent> _events =
      StreamController<SttEvent>.broadcast();

  WebSocketChannel? _socket;
  StreamSubscription<dynamic>? _socketMessages;
  StreamSubscription<Uint8List>? _audio;
  SttRequest? _request;
  Timer? _reconnectTimer;

  bool _running = false;
  bool _disposed = false;
  int _attempt = 0;
  int _generation = 0;

  @override
  Stream<SttEvent> get events => _events.stream;

  @override
  Future<Result<Unit, SttFailure>> start(SttRequest request) async {
    if (_disposed) {
      return const Err<Unit, SttFailure>(
        SttFailure(FailureCode.cancelled, isRecoverable: false),
      );
    }
    if (_running) return const Ok<Unit, SttFailure>(unit);

    // Guard before the first await.
    _running = true;
    _request = request;
    _attempt = 0;
    final int generation = ++_generation;

    final Result<Stream<Uint8List>, AudioFailure> audio = await _microphone
        .start();
    if (_superseded(generation)) return const Ok<Unit, SttFailure>(unit);

    if (audio case Err<Stream<Uint8List>, AudioFailure>(
      :final AudioFailure error,
    )) {
      _running = false;
      return Err<Unit, SttFailure>(
        SttFailure(
          error.code,
          detail: error.detail,
          isRecoverable: error.isRecoverable,
        ),
      );
    }

    final Result<Unit, SttFailure> connected = await _connect(generation);
    if (_superseded(generation)) return const Ok<Unit, SttFailure>(unit);
    if (connected.isErr) {
      _running = false;
      await _microphone.stop();
      return connected;
    }

    _audio = (audio as Ok<Stream<Uint8List>, AudioFailure>).value.listen(
      _sendAudio,
      onError: (Object error, StackTrace stackTrace) {
        _logger.log(
          LogLevel.error,
          'deepgram',
          'microphone stream error',
          error: error,
          stackTrace: stackTrace,
        );
        _emitFailure(
          SttFailure(FailureCode.microphoneUnavailable, detail: '$error'),
        );
      },
      onDone: () {
        // The microphone ended on its own. Say so rather than streaming into
        // nothing.
        if (!_running) return;
        _emit(const SttEnded(SttEndReason.audioEnded));
        unawaited(stop());
      },
    );

    return const Ok<Unit, SttFailure>(unit);
  }

  @override
  Future<void> stop() async {
    if (_disposed || !_running) return;
    _running = false;
    _generation++;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    await _audio?.cancel();
    _audio = null;
    await _microphone.stop();
    await _closeSocket(finalise: true);

    _emit(const SttEnded(SttEndReason.stoppedByUser));
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    await stop();
    _disposed = true;
    await _events.close();
  }

  bool _superseded(int generation) => _disposed || generation != _generation;

  Uri _buildUrl(SttRequest request) {
    final LanguageTag language = request.language;
    return Uri(
      scheme: 'wss',
      host: _host,
      path: '/v1/listen',
      queryParameters: <String, String>{
        'model': 'nova-2-general',
        // Urdu is asked for as Urdu. There is no Hindi substitution anywhere in
        // this file (docs/instructions.md §6).
        'language': language.code,
        'encoding': 'linear16',
        'sample_rate': '${AudioFormat.sampleRate}',
        'channels': '${AudioFormat.channels}',
        'interim_results': '${request.interimResults}',
        'punctuate': '${request.punctuate}',
        'smart_format': 'true',
        if (request.profile == SttProfile.dictation) 'endpointing': '800',
        if (request.profile == SttProfile.conversation) 'endpointing': '300',
      },
    );
  }

  Future<Result<Unit, SttFailure>> _connect(int generation) async {
    final SttRequest? request = _request;
    if (request == null) {
      return const Err<Unit, SttFailure>(
        SttFailure(FailureCode.sttStartFailed, detail: 'no request'),
      );
    }

    final Result<RecognitionToken, SttFailure> token = await _tokens.fetch();
    if (_superseded(generation)) return const Ok<Unit, SttFailure>(unit);
    if (token case Err<RecognitionToken, SttFailure>(:final SttFailure error)) {
      return Err<Unit, SttFailure>(error);
    }

    try {
      final WebSocketChannel socket = await _socketFactory(
        _buildUrl(request),
        (token as Ok<RecognitionToken, SttFailure>).value.value,
      );
      if (_superseded(generation)) {
        await socket.sink.close();
        return const Ok<Unit, SttFailure>(unit);
      }

      _socket = socket;
      _socketMessages = socket.stream.listen(
        _onMessage,
        onError: (Object error, StackTrace stackTrace) {
          _logger.log(
            LogLevel.warning,
            'deepgram',
            'socket error',
            error: error,
            stackTrace: stackTrace,
          );
          _handleTransportLoss('$error');
        },
        // Never empty: a closed socket has to be either recovered or reported
        // (B4).
        onDone: () => _handleTransportLoss(
          'socket closed (${socket.closeCode ?? 'no code'})',
        ),
      );
      return const Ok<Unit, SttFailure>(unit);
    } on Object catch (error, stackTrace) {
      _logger.log(
        LogLevel.error,
        'deepgram',
        'could not open the recognition socket',
        error: error,
        stackTrace: stackTrace,
      );
      return Err<Unit, SttFailure>(
        SttFailure(FailureCode.sttStartFailed, detail: '$error'),
      );
    }
  }

  void _sendAudio(Uint8List chunk) {
    final WebSocketChannel? socket = _socket;
    if (socket == null || !_running) return;
    try {
      socket.sink.add(chunk);
    } on Object catch (error) {
      _logger.log(LogLevel.warning, 'deepgram', 'send failed', error: error);
      _handleTransportLoss('$error');
    }
  }

  void _onMessage(dynamic message) {
    if (!_running) return;
    if (message is! String) return;

    final Object? decoded = _tryDecode(message);
    if (decoded is! Map<String, Object?>) return;

    final Object? type = decoded['type'];
    if (type == 'Metadata') return;
    if (type == 'Error' || decoded.containsKey('error')) {
      _emitFailure(
        SttFailure(
          FailureCode.sttTransportLost,
          detail: '${decoded['error'] ?? decoded['description'] ?? message}',
        ),
      );
      return;
    }

    final Object? channel = decoded['channel'];
    if (channel is! Map<String, Object?>) return;
    final Object? alternatives = channel['alternatives'];
    if (alternatives is! List<Object?> || alternatives.isEmpty) return;
    final Object? best = alternatives.first;
    if (best is! Map<String, Object?>) return;

    final Object? transcript = best['transcript'];
    if (transcript is! String || transcript.trim().isEmpty) return;

    final bool isFinal = decoded['is_final'] == true;
    if (isFinal) {
      final Object? confidence = best['confidence'];
      _emit(
        SttFinal(
          transcript,
          confidence: confidence is num ? confidence.toDouble() : null,
        ),
      );
      // A successful message proves the transport is healthy again.
      _attempt = 0;
    } else {
      _emit(SttPartial(transcript));
    }
  }

  Object? _tryDecode(String message) {
    try {
      return jsonDecode(message);
    } on FormatException catch (error) {
      _logger.log(
        LogLevel.debug,
        'deepgram',
        'unparseable message',
        error: error,
      );
      return null;
    }
  }

  void _handleTransportLoss(String detail) {
    if (_disposed || !_running) return;
    _logger.log(LogLevel.warning, 'deepgram', 'transport lost: $detail');

    unawaited(_closeSocket(finalise: false));

    if (_attempt >= maxReconnectAttempts) {
      _emitFailure(
        SttFailure(
          FailureCode.sttTransportLost,
          detail: 'gave up after $_attempt attempts: $detail',
        ),
      );
      unawaited(stop());
      return;
    }

    _attempt++;
    _emit(SttReconnecting(_attempt));
    final Duration delay =
        reconnectBackoff[(_attempt - 1).clamp(0, reconnectBackoff.length - 1)];
    final int generation = _generation;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () async {
      if (_superseded(generation) || !_running) return;
      final Result<Unit, SttFailure> reconnected = await _connect(generation);
      if (_superseded(generation) || !_running) return;
      reconnected.fold(
        (Unit _) => _emit(const SttReconnected()),
        (SttFailure failure) =>
            _handleTransportLoss(failure.detail ?? failure.message),
      );
    });
  }

  Future<void> _closeSocket({required bool finalise}) async {
    final WebSocketChannel? socket = _socket;
    _socket = null;
    await _socketMessages?.cancel();
    _socketMessages = null;
    if (socket == null) return;
    try {
      if (finalise) {
        // Tell Deepgram to flush anything it is still holding, so the last
        // words of a session are not lost.
        socket.sink.add(jsonEncode(<String, String>{'type': 'CloseStream'}));
      }
      await socket.sink.close();
    } on Object catch (error) {
      _logger.log(
        LogLevel.debug,
        'deepgram',
        'closing the socket raised',
        error: error,
      );
    }
  }

  void _emitFailure(SttFailure failure) {
    _emit(SttFailed(failure));
    _running = false;
  }

  void _emit(SttEvent event) {
    if (_disposed || _events.isClosed) return;
    _events.add(event);
  }
}
