import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/core/failure/failure.dart';
import 'package:humsukhan/core/result/result.dart';
import 'package:humsukhan/domain/speech/language_tag.dart';
import 'package:humsukhan/domain/speech/speech_failure.dart';
import 'package:humsukhan/domain/speech/stt_event.dart';
import 'package:humsukhan/domain/speech/stt_port.dart';
import 'package:humsukhan/infrastructure/stt/deepgram_stt_adapter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../fakes/fake_transport.dart';

/// Contract tests for the recognition adapter, against a fake socket.
/// No network, no Deepgram, no device.
void main() {
  late FakeMicrophone microphone;
  late FakeTokenSource tokens;
  late List<FakeSocket> sockets;
  late List<Uri> urls;
  late List<String> presentedTokens;
  late DeepgramSttAdapter adapter;

  DeepgramSttAdapter build({int maxAttempts = 3}) {
    sockets = <FakeSocket>[];
    urls = <Uri>[];
    presentedTokens = <String>[];
    return DeepgramSttAdapter(
      microphone: microphone,
      tokens: tokens,
      maxReconnectAttempts: maxAttempts,
      reconnectBackoff: const <Duration>[Duration(milliseconds: 5)],
      socketFactory: (Uri url, String token) async {
        urls.add(url);
        presentedTokens.add(token);
        final FakeSocket socket = FakeSocket();
        sockets.add(socket);
        return socket;
      },
    );
  }

  setUp(() {
    microphone = FakeMicrophone();
    tokens = FakeTokenSource();
    adapter = build();
  });

  tearDown(() async {
    await adapter.dispose();
    await microphone.dispose();
  });

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 20));

  String transcriptMessage(String text, {required bool isFinal}) =>
      jsonEncode(<String, Object?>{
        'type': 'Results',
        'is_final': isFinal,
        'channel': <String, Object?>{
          'alternatives': <Object?>[
            <String, Object?>{'transcript': text, 'confidence': 0.94},
          ],
        },
      });

  group('credentials', () {
    test(
      'the socket is opened with a short-lived token, never an API key',
      () async {
        await adapter.start(const SttRequest(language: LanguageTag.english));

        expect(tokens.fetchCount, 1);
        expect(presentedTokens.single, startsWith('ephemeral-'));
      },
    );

    test('a token failure stops the start with a reason', () async {
      tokens.failure = const SttFailure(FailureCode.sttAuthFailed);

      final Result<Unit, SttFailure> result = await adapter.start(
        const SttRequest(language: LanguageTag.english),
      );

      expect(result.isErr, isTrue);
      expect(result.errorOrNull?.code, FailureCode.sttAuthFailed);
      expect(sockets, isEmpty);
    });
  });

  group('language routing', () {
    test('Urdu asks for Urdu', () async {
      await adapter.start(const SttRequest(language: LanguageTag.urdu));
      expect(urls.single.queryParameters['language'], 'ur');
    });

    test('no request ever asks for Hindi', () async {
      for (final LanguageTag tag in LanguageTag.values) {
        final DeepgramSttAdapter fresh = build();
        await fresh.start(SttRequest(language: tag));
        expect(urls.single.queryParameters['language'], isNot('hi'));
        await fresh.dispose();
      }
    });

    test('audio is described as 16 kHz mono PCM16', () async {
      await adapter.start(const SttRequest(language: LanguageTag.english));
      final Map<String, String> query = urls.single.queryParameters;
      expect(query['encoding'], 'linear16');
      expect(query['sample_rate'], '16000');
      expect(query['channels'], '1');
    });
  });

  group('transcripts', () {
    test('an interim result becomes a partial event', () async {
      await adapter.start(const SttRequest(language: LanguageTag.english));
      final List<SttEvent> seen = <SttEvent>[];
      adapter.events.listen(seen.add);

      sockets.single.deliver(transcriptMessage('where is', isFinal: false));
      await settle();

      expect(seen.whereType<SttPartial>().single.text, 'where is');
    });

    test(
      'a settled result becomes a final event with its confidence',
      () async {
        await adapter.start(const SttRequest(language: LanguageTag.english));
        final List<SttEvent> seen = <SttEvent>[];
        adapter.events.listen(seen.add);

        sockets.single.deliver(
          transcriptMessage('where is the room', isFinal: true),
        );
        await settle();

        final SttFinal result = seen.whereType<SttFinal>().single;
        expect(result.text, 'where is the room');
        expect(result.confidence, closeTo(0.94, 0.001));
      },
    );

    test('an empty transcript is not emitted', () async {
      await adapter.start(const SttRequest(language: LanguageTag.english));
      final List<SttEvent> seen = <SttEvent>[];
      adapter.events.listen(seen.add);

      sockets.single.deliver(transcriptMessage('   ', isFinal: true));
      await settle();

      expect(seen, isEmpty);
    });

    test(
      'an unparseable message is ignored rather than crashing the stream',
      () async {
        await adapter.start(const SttRequest(language: LanguageTag.english));
        final List<SttEvent> seen = <SttEvent>[];
        adapter.events.listen(seen.add);

        sockets.single.deliver('not json at all');
        sockets.single.deliver(
          transcriptMessage('still working', isFinal: true),
        );
        await settle();

        expect(seen.whereType<SttFinal>().single.text, 'still working');
      },
    );

    test('a service error message becomes a failure event', () async {
      await adapter.start(const SttRequest(language: LanguageTag.english));
      final List<SttEvent> seen = <SttEvent>[];
      adapter.events.listen(seen.add);

      sockets.single.deliver(
        jsonEncode(<String, Object?>{'type': 'Error', 'error': 'bad audio'}),
      );
      await settle();

      expect(
        seen.whereType<SttFailed>().single.cause.detail,
        contains('bad audio'),
      );
    });
  });

  group('B4 — a lost transport is never silent', () {
    test('a dropped socket reconnects and says so', () async {
      await adapter.start(const SttRequest(language: LanguageTag.english));
      final List<SttEvent> seen = <SttEvent>[];
      adapter.events.listen(seen.add);

      await sockets.single.drop();
      await settle();

      expect(seen.whereType<SttReconnecting>(), isNotEmpty);
      expect(seen.whereType<SttReconnected>(), isNotEmpty);
      expect(sockets.length, 2, reason: 'a second socket must be opened');
    });

    test('recognition continues on the new socket', () async {
      await adapter.start(const SttRequest(language: LanguageTag.english));
      final List<SttEvent> seen = <SttEvent>[];
      adapter.events.listen(seen.add);

      await sockets.first.drop();
      await settle();
      sockets.last.deliver(transcriptMessage('after the drop', isFinal: true));
      await settle();

      expect(seen.whereType<SttFinal>().single.text, 'after the drop');
    });

    test('exhausting the attempts ends in a failure, not silence', () async {
      adapter = build(maxAttempts: 2);
      await adapter.start(const SttRequest(language: LanguageTag.english));
      final List<SttEvent> seen = <SttEvent>[];
      adapter.events.listen(seen.add);

      for (int i = 0; i < 4; i++) {
        if (sockets.isEmpty) break;
        await sockets.last.drop();
        await settle();
      }

      expect(
        seen.whereType<SttFailed>(),
        isNotEmpty,
        reason: 'giving up must be announced',
      );
    });

    test(
      'a transport error reconnects rather than killing the stream',
      () async {
        await adapter.start(const SttRequest(language: LanguageTag.english));
        final List<SttEvent> seen = <SttEvent>[];
        adapter.events.listen(seen.add);

        sockets.single.error(StateError('connection reset'));
        await settle();

        expect(seen.whereType<SttReconnecting>(), isNotEmpty);
      },
    );
  });

  group('microphone', () {
    test('a refused microphone fails the start with its own reason', () async {
      microphone.failOnStart = const AudioFailure(
        FailureCode.microphonePermissionDenied,
      );

      final Result<Unit, SttFailure> result = await adapter.start(
        const SttRequest(language: LanguageTag.english),
      );

      expect(result.errorOrNull?.code, FailureCode.microphonePermissionDenied);
      expect(sockets, isEmpty);
    });

    test('audio is forwarded to the socket', () async {
      await adapter.start(const SttRequest(language: LanguageTag.english));

      microphone.emit(Uint8List.fromList(<int>[1, 2, 3, 4]));
      await settle();

      expect(sockets.single.sent, isNotEmpty);
    });

    test('the audio stream ending is announced', () async {
      await adapter.start(const SttRequest(language: LanguageTag.english));
      final List<SttEvent> seen = <SttEvent>[];
      adapter.events.listen(seen.add);

      await microphone.end();
      await settle();

      expect(seen.whereType<SttEnded>(), isNotEmpty);
    });
  });

  group('stopping', () {
    test('stop flushes the service and announces the end', () async {
      await adapter.start(const SttRequest(language: LanguageTag.english));
      final List<SttEvent> seen = <SttEvent>[];
      adapter.events.listen(seen.add);
      final FakeSocket socket = sockets.single;

      await adapter.stop();
      await settle();

      expect(
        socket.sent.whereType<String>().any(
          (String s) => s.contains('CloseStream'),
        ),
        isTrue,
        reason: 'the last words of a session must not be dropped',
      );
      expect(
        seen.whereType<SttEnded>().single.reason,
        SttEndReason.stoppedByUser,
      );
      expect(microphone.stopCount, greaterThan(0));
    });

    test('stopping after a stop is harmless', () async {
      await adapter.start(const SttRequest(language: LanguageTag.english));
      await adapter.stop();
      await adapter.stop();
    });

    test(
      'a second start while running does not open a second socket',
      () async {
        await adapter.start(const SttRequest(language: LanguageTag.english));
        await adapter.start(const SttRequest(language: LanguageTag.english));

        expect(sockets.length, 1);
      },
    );
  });

  test('the fake socket satisfies the real WebSocketChannel interface', () {
    expect(FakeSocket(), isA<WebSocketChannel>());
  });
}
