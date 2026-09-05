import 'dart:async';
import 'dart:typed_data';

import 'package:humsukhan/core/result/result.dart';
import 'package:humsukhan/domain/speech/speech_failure.dart';
import 'package:humsukhan/infrastructure/audio/microphone_source.dart';
import 'package:humsukhan/infrastructure/backend/backend_gateway.dart';
import 'package:humsukhan/infrastructure/stt/recognition_token.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// A microphone whose audio the test supplies.
final class FakeMicrophone implements MicrophoneSource {
  /// Creates a fake microphone.
  FakeMicrophone();

  // ignore: close_sinks — closed by dispose(), which every test calls.
  StreamController<Uint8List>? _controller;

  /// How many times [start] was called.
  int startCount = 0;

  /// How many times [stop] was called.
  int stopCount = 0;

  /// When set, [start] fails with this.
  AudioFailure? failOnStart;

  @override
  Future<Result<Unit, AudioFailure>> ensurePermission() async {
    final AudioFailure? failure = failOnStart;
    if (failure != null) return Err<Unit, AudioFailure>(failure);
    return const Ok<Unit, AudioFailure>(unit);
  }

  @override
  Future<Result<Stream<Uint8List>, AudioFailure>> start() async {
    startCount++;
    final AudioFailure? failure = failOnStart;
    if (failure != null) {
      return Err<Stream<Uint8List>, AudioFailure>(failure);
    }
    // ignore: close_sinks — handed to _controller and closed by dispose().
    final StreamController<Uint8List> controller =
        StreamController<Uint8List>.broadcast();
    _controller = controller;
    return Ok<Stream<Uint8List>, AudioFailure>(controller.stream);
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }

  @override
  Future<void> dispose() async {
    await _controller?.close();
  }

  /// Pushes audio to whoever is listening.
  void emit(Uint8List bytes) {
    final StreamController<Uint8List>? controller = _controller;
    if (controller != null && !controller.isClosed) controller.add(bytes);
  }

  /// Ends the audio stream, as a revoked permission would.
  Future<void> end() async {
    await _controller?.close();
    _controller = null;
  }
}

/// A token source the test controls.
final class FakeTokenSource implements RecognitionTokenSource {
  /// Creates a token source.
  FakeTokenSource();

  /// How many tokens were minted.
  int fetchCount = 0;

  /// When set, [fetch] fails with this.
  SttFailure? failure;

  @override
  Future<Result<RecognitionToken, SttFailure>> fetch() async {
    fetchCount++;
    final SttFailure? f = failure;
    if (f != null) return Err<RecognitionToken, SttFailure>(f);
    return Ok<RecognitionToken, SttFailure>(
      RecognitionToken(
        value: 'ephemeral-$fetchCount',
        expiresAt: DateTime.now().add(const Duration(seconds: 30)),
      ),
    );
  }
}

/// A WebSocket the test drives from both ends.
final class FakeSocket extends StreamChannelMixin<dynamic>
    implements WebSocketChannel {
  /// Creates a socket.
  FakeSocket()
    : _incoming = StreamController<dynamic>.broadcast(),
      _outgoing = StreamController<dynamic>.broadcast() {
    _sink = _FakeSink(_outgoing, this);
  }

  // ignore: close_sinks — both controllers are closed by _close().
  final StreamController<dynamic> _incoming;
  // ignore: close_sinks — both controllers are closed by _close().
  final StreamController<dynamic> _outgoing;
  // ignore: close_sinks — the sink closes with the socket, in _close().
  late final _FakeSink _sink;

  /// Everything the adapter sent.
  final List<Object?> sent = <Object?>[];

  /// Whether the adapter closed this socket.
  bool closed = false;

  @override
  Stream<dynamic> get stream => _incoming.stream;

  @override
  WebSocketSink get sink => _sink;

  @override
  Future<void> get ready async {}

  @override
  int? get closeCode => closed ? 1000 : null;

  @override
  String? get closeReason => null;

  @override
  String? get protocol => 'token';

  /// Delivers a server message.
  void deliver(String message) {
    if (!_incoming.isClosed) _incoming.add(message);
  }

  /// Drops the connection as a network failure would.
  Future<void> drop() async {
    await _incoming.close();
  }

  /// Pushes a transport error.
  void error(Object error) {
    if (!_incoming.isClosed) _incoming.addError(error);
  }

  Future<void> _close() async {
    closed = true;
    await _incoming.close();
    await _outgoing.close();
  }
}

final class _FakeSink implements WebSocketSink {
  _FakeSink(this._controller, this._owner);

  final StreamController<dynamic> _controller;
  final FakeSocket _owner;

  @override
  void add(dynamic data) {
    _owner.sent.add(data);
    if (!_controller.isClosed) _controller.add(data);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    if (!_controller.isClosed) _controller.addError(error, stackTrace);
  }

  @override
  Future<void> addStream(Stream<dynamic> stream) => stream.forEach(add);

  @override
  Future<void> close([int? closeCode, String? closeReason]) => _owner._close();

  @override
  Future<void> get done => _controller.done;
}

/// A backend whose responses the test dictates.
final class FakeBackendGateway implements BackendGateway {
  /// Creates a fake gateway.
  FakeBackendGateway();

  /// Every function invoked, with its body.
  final List<(String, Map<String, Object?>)> calls =
      <(String, Map<String, Object?>)>[];

  /// Responses by function name.
  final Map<String, Map<String, Object?>> responses =
      <String, Map<String, Object?>>{};

  /// Failures by function name.
  final Map<String, BackendFailure> failures = <String, BackendFailure>{};

  @override
  Future<Result<Map<String, Object?>, BackendFailure>> invoke(
    String name, {
    Map<String, Object?> body = const <String, Object?>{},
  }) async {
    calls.add((name, body));
    final BackendFailure? failure = failures[name];
    if (failure != null) {
      return Err<Map<String, Object?>, BackendFailure>(failure);
    }
    return Ok<Map<String, Object?>, BackendFailure>(
      responses[name] ?? const <String, Object?>{},
    );
  }
}
