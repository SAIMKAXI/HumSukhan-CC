import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/application/environment/monitoring_controller.dart';
import 'package:humsukhan/core/failure/failure.dart';
import 'package:humsukhan/core/result/result.dart';
import 'package:humsukhan/domain/environment/detector_port.dart';
import 'package:humsukhan/domain/environment/model_state.dart';
import 'package:humsukhan/domain/environment/sound_event.dart';
import 'package:humsukhan/domain/settings/app_settings.dart';

import '../../fakes/fake_app_ports.dart';
import '../../fakes/fake_speech_ports.dart';

void main() {
  late FakeSoundDetector detector;
  late FakeModelRepository models;
  late RecordingAlertPresenter presenter;
  late FakeClock clock;
  late RecordingQuickTile tile;
  late MonitoringController controller;

  setUp(() {
    detector = FakeSoundDetector();
    models = FakeModelRepository();
    presenter = RecordingAlertPresenter();
    clock = FakeClock();
    tile = RecordingQuickTile();
    controller = MonitoringController(
      detector: detector,
      models: models,
      presenter: presenter,
      tile: tile,
      ids: FakeIdGenerator(prefix: 'e'),
      clock: clock,
    );
  });

  tearDown(() async {
    await tile.dispose();
    await controller.dispose();
    await detector.dispose();
    await models.dispose();
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  group('starting', () {
    test('a ready model lets monitoring start', () async {
      final Result<Unit, Failure> result = await controller.start();

      expect(result.isOk, isTrue);
      expect(controller.state.phase, MonitoringPhase.active);
      expect(detector.startCount, 1);
    });

    test(
      'B6 — a model that will not load blocks the start with a reason',
      () async {
        models.nextState = const ModelFailed(
          ModelFailure(FailureCode.modelCorrupt),
        );

        final Result<Unit, Failure> result = await controller.start();

        expect(result.isErr, isTrue);
        expect(controller.state.phase, MonitoringPhase.failed);
        expect(controller.state.failure?.code, FailureCode.modelCorrupt);
        expect(
          controller.state.failure?.remedy,
          isNotNull,
          reason: 'a blocked safety feature must name the way out',
        );
        expect(detector.startCount, 0);
      },
    );

    test('an absent model is a named failure, not a silent no-op', () async {
      models.nextState = const ModelAbsent();

      await controller.start();

      expect(controller.state.failure?.code, FailureCode.modelAbsent);
    });

    test('a detector that refuses to start says why', () async {
      detector.failOnStart = const DetectorFailure(
        FailureCode.microphonePermissionDenied,
      );

      await controller.start();

      expect(controller.state.phase, MonitoringPhase.failed);
      expect(
        controller.state.failure?.code,
        FailureCode.microphonePermissionDenied,
      );
    });

    test('starting twice opens one detector', () async {
      await Future.wait<Result<Unit, Failure>>(<Future<Result<Unit, Failure>>>[
        controller.start(),
        controller.start(),
      ]);

      expect(detector.startCount, 1);
    });
  });

  group('detection', () {
    test(
      'a confirmed critical sound alerts through the chosen channels',
      () async {
        controller.setChannels(const AlertChannels(torch: true));
        await controller.start();

        detector.observe(SoundKind.alarm, 0.95, clock.now());
        await settle();

        expect(controller.state.events.single.kind, SoundKind.alarm);
        expect(presenter.presented.single.kind, SoundKind.alarm);
        expect(presenter.channels.single.torch, isTrue);
      },
    );

    test('an unconfirmed non-critical sound does not alert', () async {
      await controller.start();

      detector.observe(SoundKind.dogBark, 0.6, clock.now());
      await settle();

      expect(controller.state.events, isEmpty);
      expect(presenter.presented, isEmpty);
    });

    test('a second window confirms and alerts', () async {
      await controller.start();

      detector.observe(SoundKind.doorbell, 0.6, clock.now());
      await settle();
      detector.observe(
        SoundKind.doorbell,
        0.6,
        clock.now().add(const Duration(seconds: 2)),
      );
      await settle();

      expect(controller.state.events.single.kind, SoundKind.doorbell);
    });

    test('a quiet observation is ignored entirely', () async {
      await controller.start();

      detector.observe(SoundKind.siren, 0.05, clock.now());
      await settle();

      expect(controller.state.events, isEmpty);
    });

    test('a failing alert channel does not take monitoring down', () async {
      presenter.throwOnPresent = true;
      await controller.start();

      detector.observe(SoundKind.siren, 0.95, clock.now());
      await settle();
      await settle();

      expect(controller.state.phase, MonitoringPhase.active);
      expect(controller.state.events.single.kind, SoundKind.siren);
    });

    test('newest alerts come first', () async {
      await controller.start();

      detector.observe(SoundKind.siren, 0.95, clock.now());
      await settle();
      clock.advance(const Duration(minutes: 1));
      detector.observe(SoundKind.glassBreak, 0.95, clock.now());
      await settle();

      expect(controller.state.events.first.kind, SoundKind.glassBreak);
    });
  });

  group('failing while running', () {
    test('a detector failure surfaces with its reason', () async {
      await controller.start();

      detector.fail(const DetectorFailure(FailureCode.microphoneUnavailable));
      await settle();

      expect(controller.state.phase, MonitoringPhase.failed);
      expect(controller.state.failure?.code, FailureCode.microphoneUnavailable);
    });

    test(
      'a detector stream that closes while monitoring is a failure',
      () async {
        await controller.start();

        await detector.die();
        await settle();

        expect(
          controller.state.phase,
          MonitoringPhase.failed,
          reason: 'a safety feature must never fail closed and silent',
        );
      },
    );
  });

  group('history', () {
    test('acknowledging marks one event, not all of them', () async {
      await controller.start();
      detector.observe(SoundKind.siren, 0.95, clock.now());
      await settle();
      clock.advance(const Duration(minutes: 1));
      detector.observe(SoundKind.alarm, 0.95, clock.now());
      await settle();

      controller.acknowledge(controller.state.events.last);

      expect(controller.state.events.first.acknowledged, isFalse);
      expect(controller.state.events.last.acknowledged, isTrue);
    });

    test('clearing empties the history', () async {
      await controller.start();
      detector.observe(SoundKind.siren, 0.95, clock.now());
      await settle();

      controller.clearHistory();

      expect(controller.state.events, isEmpty);
    });
  });

  group('the Quick Settings tile is told the truth', () {
    test('starting publishes that monitoring is on', () async {
      await controller.start();
      expect(tile.published, <bool>[true]);
    });

    test('stopping publishes that it is off', () async {
      await controller.start();
      await controller.stop();
      expect(tile.published, <bool>[true, false]);
    });

    test(
      'a failure publishes off, so the tile never claims protection',
      () async {
        detector.failOnStart = const DetectorFailure(
          FailureCode.microphoneUnavailable,
        );

        await controller.start();

        expect(
          tile.published,
          contains(false),
          reason: 'a tile showing "on" while nothing is listening is a lie',
        );
        expect(tile.published, isNot(contains(true)));
      },
    );
  });

  group('stopping', () {
    test('stopping closes the detector and clears any failure', () async {
      await controller.start();
      detector.fail(const DetectorFailure(FailureCode.microphoneUnavailable));
      await settle();

      await controller.stop();

      expect(controller.state.phase, MonitoringPhase.off);
      expect(controller.state.failure, isNull);
      expect(detector.stopCount, 1);
    });
  });
}
