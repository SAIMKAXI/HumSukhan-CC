import 'dart:developer' as developer;

/// Severity of a log record.
enum LogLevel {
  /// Fine-grained tracing, off in release.
  debug,

  /// Notable lifecycle events.
  info,

  /// Something recovered, but a user may have noticed.
  warning,

  /// Something failed.
  error,
}

/// A minimal logging port so no layer reaches for `print` and so tests can
/// assert on what was recorded.
abstract interface class AppLogger {
  /// Records [message] under [name] at [level].
  void log(
    LogLevel level,
    String name,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  });
}

/// Writes to `dart:developer`, which is inert in release builds.
final class DeveloperLogger implements AppLogger {
  /// Creates a logger that drops records below [minimum].
  const DeveloperLogger({this.minimum = LogLevel.debug});

  /// The lowest level that is recorded.
  final LogLevel minimum;

  @override
  void log(
    LogLevel level,
    String name,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (level.index < minimum.index) return;
    developer.log(
      message,
      name: 'humsukhan.$name',
      level: switch (level) {
        LogLevel.debug => 500,
        LogLevel.info => 800,
        LogLevel.warning => 900,
        LogLevel.error => 1000,
      },
      error: error,
      stackTrace: stackTrace,
    );
  }
}

/// Discards every record. Used by tests that do not assert on logging.
final class SilentLogger implements AppLogger {
  /// Creates a logger that records nothing.
  const SilentLogger();

  @override
  void log(
    LogLevel level,
    String name,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {}
}
