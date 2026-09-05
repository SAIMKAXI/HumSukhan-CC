/// How urgently a detected sound should be surfaced.
enum AlertSeverity {
  /// Safety-critical: alarms, sirens, breaking glass.
  critical,

  /// Worth interrupting for: doorbell, knock, a baby crying.
  high,

  /// Informational: a dog, a horn, a phone.
  normal,
}

/// A sound HumSukhan can recognise.
///
/// A closed set: the app promises these nine and says so on screen. Each maps to
/// AudioSet class indices in the environment's detector adapter.
enum SoundKind {
  /// Emergency vehicle or civil-defence siren.
  siren(AlertSeverity.critical),

  /// A smoke, fire, car or clock alarm.
  alarm(AlertSeverity.critical),

  /// Glass breaking or shattering.
  glassBreak(AlertSeverity.critical),

  /// A doorbell.
  doorbell(AlertSeverity.high),

  /// Knocking at a door.
  knock(AlertSeverity.high),

  /// An infant crying.
  babyCry(AlertSeverity.high),

  /// A dog barking or howling.
  dogBark(AlertSeverity.normal),

  /// A vehicle horn.
  vehicleHorn(AlertSeverity.normal),

  /// A telephone ringing.
  phone(AlertSeverity.normal);

  const SoundKind(this.severity);

  /// How urgent this kind of sound is.
  final AlertSeverity severity;

  /// Parses a stored name, or `null` when it is not one of ours.
  static SoundKind? fromName(String? name) {
    for (final SoundKind kind in SoundKind.values) {
      if (kind.name == name) return kind;
    }
    return null;
  }
}

/// A sound that was detected, confirmed, and shown to the user.
final class SoundEvent {
  /// Creates a detected event.
  const SoundEvent({
    required this.id,
    required this.kind,
    required this.confidence,
    required this.detectedAt,
    this.acknowledged = false,
  });

  /// Stable identity.
  final String id;

  /// What was heard.
  final SoundKind kind;

  /// Detector confidence in `0..1` at the moment of confirmation.
  final double confidence;

  /// When it was confirmed.
  final DateTime detectedAt;

  /// Whether the user has dismissed it.
  final bool acknowledged;

  /// How urgent it is.
  AlertSeverity get severity => kind.severity;

  /// A copy marked acknowledged.
  SoundEvent acknowledge() => SoundEvent(
    id: id,
    kind: kind,
    confidence: confidence,
    detectedAt: detectedAt,
    acknowledged: true,
  );

  @override
  bool operator ==(Object other) =>
      other is SoundEvent &&
      other.id == id &&
      other.kind == kind &&
      other.confidence == confidence &&
      other.detectedAt == detectedAt &&
      other.acknowledged == acknowledged;

  @override
  int get hashCode =>
      Object.hash(id, kind, confidence, detectedAt, acknowledged);

  @override
  String toString() =>
      'SoundEvent(${kind.name}, ${confidence.toStringAsFixed(2)})';
}
