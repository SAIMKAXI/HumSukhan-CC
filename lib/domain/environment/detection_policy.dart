import 'package:humsukhan/domain/environment/sound_event.dart';

/// One classifier output for one analysis window.
final class SoundObservation {
  /// Creates an observation.
  const SoundObservation({
    required this.kind,
    required this.confidence,
    required this.at,
  });

  /// What the classifier thinks it heard.
  final SoundKind kind;

  /// How sure it is, in `0..1`.
  final double confidence;

  /// When the window ended.
  final DateTime at;
}

/// Whether an observation should raise an alert.
///
/// A pure decision function so temporal confirmation is testable without audio:
/// a single confident window is not enough for anything but a critical sound,
/// and a kind that has just alerted does not alert again immediately.
final class DetectionPolicy {
  /// Creates a policy.
  const DetectionPolicy({
    this.minimumConfidence = 0.45,
    this.strongConfidence = 0.72,
    this.confirmationWindow = const Duration(seconds: 6),
    this.repeatSuppression = const Duration(seconds: 20),
  });

  /// Below this, an observation is ignored outright.
  final double minimumConfidence;

  /// At or above this, one window is enough for a critical sound.
  final double strongConfidence;

  /// How far back a supporting observation may be to still count.
  final Duration confirmationWindow;

  /// How long after alerting for a kind that kind stays quiet.
  final Duration repeatSuppression;

  /// How many windows must agree before a non-critical sound alerts.
  static const int requiredHits = 2;

  /// Whether [observation] should alert, given the recent [history] for the same
  /// kind (most recent last) and when that kind [lastAlertedAt].
  bool shouldAlert({
    required SoundObservation observation,
    required List<SoundObservation> history,
    DateTime? lastAlertedAt,
  }) {
    if (observation.confidence < minimumConfidence) return false;

    if (lastAlertedAt != null &&
        observation.at.difference(lastAlertedAt) < repeatSuppression) {
      return false;
    }

    final bool critical = observation.kind.severity == AlertSeverity.critical;
    if (critical && observation.confidence >= strongConfidence) return true;

    final int supporting = history
        .where(
          (SoundObservation o) =>
              o.kind == observation.kind &&
              o.confidence >= minimumConfidence &&
              observation.at.difference(o.at) <= confirmationWindow &&
              !observation.at.isBefore(o.at),
        )
        .length;

    // The observation itself counts as one hit.
    return supporting + 1 >= requiredHits;
  }
}
