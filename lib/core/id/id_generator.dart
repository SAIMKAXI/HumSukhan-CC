/// Makes the stable identifiers entities are keyed by.
///
/// A port rather than a static call, so tests get deterministic ids and a
/// caption list can be asserted exactly.
abstract interface class IdGenerator {
  /// A new identifier, unique within this run.
  String next();
}

/// Monotonic ids with a random-enough prefix for local storage.
final class TimestampIdGenerator implements IdGenerator {
  /// Creates a generator.
  TimestampIdGenerator();

  int _counter = 0;

  @override
  String next() {
    _counter++;
    return '${DateTime.now().microsecondsSinceEpoch}-$_counter';
  }
}
