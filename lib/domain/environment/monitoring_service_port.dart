import 'package:humsukhan/core/result/result.dart';
import 'package:humsukhan/domain/environment/detector_port.dart';

/// Keeps the process alive while monitoring runs.
///
/// Android kills a backgrounded app's microphone within seconds without a typed
/// foreground service. The notification is not decoration: it is what makes
/// "HumSukhan is listening" true and visible.
abstract interface class MonitoringServicePort {
  /// Starts the foreground service.
  Future<Result<Unit, DetectorFailure>> start({
    required String title,
    required String body,
  });

  /// Stops it.
  Future<void> stop();

  /// Whether it is running.
  Future<bool> isRunning();
}
