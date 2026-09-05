/// The current time, as a dependency.
///
/// Everything that stamps an entity takes one of these, so retention countdowns
/// and detection windows are testable without waiting.
abstract interface class Clock {
  /// Now.
  DateTime now();
}

/// The real clock.
final class SystemClock implements Clock {
  /// Creates a system clock.
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}
