import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:humsukhan/core/failure/failure.dart';
import 'package:humsukhan/core/logging/app_logger.dart';
import 'package:humsukhan/core/result/result.dart';
import 'package:humsukhan/domain/environment/detector_port.dart';
import 'package:humsukhan/domain/environment/monitoring_service_port.dart';

/// [MonitoringServicePort] over `flutter_foreground_task`.
final class ForegroundMonitoringService implements MonitoringServicePort {
  /// Creates a service wrapper.
  ForegroundMonitoringService({AppLogger logger = const SilentLogger()})
    : _logger = logger;

  final AppLogger _logger;
  bool _configured = false;

  void _configure({required String channelName, required String channelBody}) {
    if (_configured) return;
    _configured = true;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'humsukhan_monitoring',
        channelName: channelName,
        channelDescription: channelBody,
        // The defaults are already low importance: the notification must be
        // visible, not intrusive. The alert itself is haptic and visual.
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        // No periodic callback: detection is driven by the audio stream in the
        // app isolate, and the wake lock is what keeps it running.
        eventAction: ForegroundTaskEventAction.nothing(),
      ),
    );
  }

  @override
  Future<Result<Unit, DetectorFailure>> start({
    required String title,
    required String body,
  }) async {
    try {
      _configure(channelName: title, channelBody: body);

      final NotificationPermission permission =
          await FlutterForegroundTask.checkNotificationPermission();
      if (permission != NotificationPermission.granted) {
        final NotificationPermission requested =
            await FlutterForegroundTask.requestNotificationPermission();
        if (requested != NotificationPermission.granted) {
          // Named, not silent: the user is told which permission is missing.
          return const Err<Unit, DetectorFailure>(
            DetectorFailure(FailureCode.notificationPermissionDenied),
          );
        }
      }

      if (await FlutterForegroundTask.isRunningService) {
        return const Ok<Unit, DetectorFailure>(unit);
      }

      final ServiceRequestResult result =
          await FlutterForegroundTask.startService(
            serviceTypes: <ForegroundServiceTypes>[
              ForegroundServiceTypes.microphone,
            ],
            notificationTitle: title,
            notificationText: body,
          );
      if (result is ServiceRequestSuccess) {
        return const Ok<Unit, DetectorFailure>(unit);
      }
      return Err<Unit, DetectorFailure>(
        DetectorFailure(
          FailureCode.serviceStartFailed,
          detail: result.toString(),
        ),
      );
    } on Object catch (error, stackTrace) {
      _logger.log(
        LogLevel.error,
        'service',
        'the foreground service would not start',
        error: error,
        stackTrace: stackTrace,
      );
      return Err<Unit, DetectorFailure>(
        DetectorFailure(FailureCode.serviceStartFailed, detail: '$error'),
      );
    }
  }

  @override
  Future<void> stop() async {
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } on Object catch (error) {
      _logger.log(
        LogLevel.warning,
        'service',
        'stopping the foreground service raised',
        error: error,
      );
    }
  }

  @override
  Future<bool> isRunning() async {
    try {
      return await FlutterForegroundTask.isRunningService;
    } on Object catch (error) {
      _logger.log(
        LogLevel.debug,
        'service',
        'service state unknown',
        error: error,
      );
      return false;
    }
  }
}
