import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/application/common/operation_state.dart';
import 'package:humsukhan/application/professional/insight_service.dart';
import 'package:humsukhan/core/failure/failure.dart';
import 'package:humsukhan/core/result/result.dart';
import 'package:humsukhan/domain/professional/insight.dart';
import 'package:humsukhan/domain/professional/insight_port.dart';
import 'package:humsukhan/domain/speech/language_tag.dart';

import '../../fakes/fake_app_ports.dart';

void main() {
  late FakeInsightPort port;
  late InsightService service;

  setUp(() {
    port = FakeInsightPort();
    service = InsightService(port: port);
  });

  tearDown(() async => service.dispose());

  Future<Result<Insight, InsightFailure>> generate([
    String transcript = 'a b c',
  ]) => service.generate(transcript: transcript, language: LanguageTag.english);

  group('B7 — never-requested, in-progress and failed are distinguishable', () {
    test('a fresh service is idle, not empty', () {
      expect(service.state, isA<OperationIdle<Insight>>());
    });

    test('generation moves through loading to success', () async {
      port.delay = const Duration(milliseconds: 20);
      final Future<Result<Insight, InsightFailure>> pending = generate();

      expect(service.state, isA<OperationLoading<Insight>>());
      await pending;
      expect(service.state, isA<OperationSuccess<Insight>>());
    });

    test(
      'a port failure becomes a failure state carrying the reason',
      () async {
        port.failure = const InsightFailure(FailureCode.network);

        await generate();

        expect(service.state, isA<OperationFailure<Insight>>());
        expect(service.state.failureOrNull?.code, FailureCode.network);
        expect(service.state.failureOrNull?.remedy, isNotNull);
      },
    );

    test(
      'an empty transcript fails with its own reason, not a blank screen',
      () async {
        final Result<Insight, InsightFailure> result = await generate('   ');

        expect(result.isErr, isTrue);
        expect(
          service.state.failureOrNull?.code,
          FailureCode.insightTranscriptEmpty,
        );
        expect(port.requests, isEmpty);
      },
    );

    test(
      'a model returning nothing usable is a failure, not a success',
      () async {
        port.result = Insight(summary: '   ', generatedAt: DateTime.utc(2026));

        final Result<Insight, InsightFailure> result = await generate();

        expect(result.isErr, isTrue);
        expect(service.state, isA<OperationFailure<Insight>>());
      },
    );

    test('every failure path changes state', () async {
      // The shipped bug returned early on five distinct failures with no state
      // change at all. Each path here must move the state machine.
      for (final InsightFailure failure in <InsightFailure>[
        const InsightFailure(FailureCode.network),
        const InsightFailure(FailureCode.offline),
        const InsightFailure(FailureCode.timeout),
        const InsightFailure(FailureCode.authNoSession),
        const InsightFailure(FailureCode.insightGenerationFailed),
      ]) {
        service.reset();
        port.failure = failure;
        await generate();
        expect(
          service.state,
          isA<OperationFailure<Insight>>(),
          reason: 'no state change for ${failure.code.name}',
        );
      }
    });
  });

  group('concurrency', () {
    test(
      'a second request while one is in flight is refused, not queued',
      () async {
        port.delay = const Duration(milliseconds: 30);
        final Future<Result<Insight, InsightFailure>> first = generate();
        final Result<Insight, InsightFailure> second = await generate();

        expect(second.isErr, isTrue);
        await first;
        expect(port.requests.length, 1);
      },
    );
  });

  group('seeding', () {
    test('a stored insight seeds success without a request', () {
      service.seed(Insight(summary: 'stored', generatedAt: DateTime.utc(2026)));

      expect(service.state, isA<OperationSuccess<Insight>>());
      expect(port.requests, isEmpty);
    });

    test('seeding null returns to idle', () {
      service.seed(null);
      expect(service.state, isA<OperationIdle<Insight>>());
    });
  });

  test('generating after dispose fails rather than throwing', () async {
    await service.dispose();
    expect((await generate()).isErr, isTrue);
  });
}
