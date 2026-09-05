import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/domain/environment/detection_policy.dart';
import 'package:humsukhan/domain/environment/sound_event.dart';

void main() {
  const DetectionPolicy policy = DetectionPolicy();
  final DateTime t0 = DateTime(2026, 3, 1, 9);

  SoundObservation obs(SoundKind kind, double confidence, int secondsIn) =>
      SoundObservation(
        kind: kind,
        confidence: confidence,
        at: t0.add(Duration(seconds: secondsIn)),
      );

  test('a quiet observation never alerts', () {
    expect(
      policy.shouldAlert(
        observation: obs(SoundKind.siren, 0.2, 0),
        history: const <SoundObservation>[],
      ),
      isFalse,
    );
  });

  test('one strongly confident critical sound alerts immediately', () {
    expect(
      policy.shouldAlert(
        observation: obs(SoundKind.alarm, 0.9, 0),
        history: const <SoundObservation>[],
      ),
      isTrue,
    );
  });

  test('a single moderate non-critical observation waits for confirmation', () {
    expect(
      policy.shouldAlert(
        observation: obs(SoundKind.dogBark, 0.6, 0),
        history: const <SoundObservation>[],
      ),
      isFalse,
    );
  });

  test('two observations inside the window confirm each other', () {
    expect(
      policy.shouldAlert(
        observation: obs(SoundKind.doorbell, 0.6, 2),
        history: <SoundObservation>[obs(SoundKind.doorbell, 0.55, 0)],
      ),
      isTrue,
    );
  });

  test('an observation too long ago does not confirm', () {
    expect(
      policy.shouldAlert(
        observation: obs(SoundKind.doorbell, 0.6, 30),
        history: <SoundObservation>[obs(SoundKind.doorbell, 0.55, 0)],
      ),
      isFalse,
    );
  });

  test('a different sound does not confirm', () {
    expect(
      policy.shouldAlert(
        observation: obs(SoundKind.doorbell, 0.6, 2),
        history: <SoundObservation>[obs(SoundKind.dogBark, 0.9, 0)],
      ),
      isFalse,
    );
  });

  test('the same kind does not alert twice in quick succession', () {
    expect(
      policy.shouldAlert(
        observation: obs(SoundKind.alarm, 0.95, 5),
        history: const <SoundObservation>[],
        lastAlertedAt: t0,
      ),
      isFalse,
    );
  });

  test('suppression expires, so a continuing alarm alerts again', () {
    expect(
      policy.shouldAlert(
        observation: obs(SoundKind.alarm, 0.95, 60),
        history: const <SoundObservation>[],
        lastAlertedAt: t0,
      ),
      isTrue,
    );
  });

  test('severity is a property of the sound, not of the caller', () {
    expect(SoundKind.siren.severity, AlertSeverity.critical);
    expect(SoundKind.doorbell.severity, AlertSeverity.high);
    expect(SoundKind.phone.severity, AlertSeverity.normal);
  });
}
