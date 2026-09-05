import 'dart:async';

import 'package:humsukhan/core/logging/app_logger.dart';
import 'package:humsukhan/domain/environment/alert_presenter_port.dart';
import 'package:humsukhan/domain/environment/sound_event.dart';
import 'package:humsukhan/domain/settings/app_settings.dart';
import 'package:torch_light/torch_light.dart';
import 'package:vibration/vibration.dart';

/// Shows an alert on screen. Registered by the app shell, because only the
/// widget tree can put something in front of the user.
typedef VisualAlertSink = void Function(SoundEvent event);

/// Raises alerts through every non-auditory channel the user has enabled.
///
/// One channel failing never cancels the others: a Deaf user who has torch
/// alerts on a device with no torch must still feel the vibration.
final class DeviceAlertPresenter implements AlertPresenterPort {
  /// Creates a presenter.
  DeviceAlertPresenter({
    VisualAlertSink? onVisual,
    AppLogger logger = const SilentLogger(),
  }) : _onVisual = onVisual,
       _logger = logger;

  final VisualAlertSink? _onVisual;
  final AppLogger _logger;

  /// Vibration patterns, longest for the most urgent sounds.
  static const Map<AlertSeverity, List<int>> _patterns =
      <AlertSeverity, List<int>>{
        AlertSeverity.critical: <int>[0, 400, 150, 400, 150, 400],
        AlertSeverity.high: <int>[0, 300, 200, 300],
        AlertSeverity.normal: <int>[0, 200],
      };

  @override
  Future<void> present(SoundEvent event, AlertChannels channels) async {
    // Each channel is attempted independently.
    if (channels.haptic) await _vibrate(event.severity);
    if (channels.torch) await _flashTorch(event.severity);
    if (channels.visual || channels.screenFlash) {
      final VisualAlertSink? sink = _onVisual;
      if (sink != null) {
        sink(event);
      } else {
        _logger.log(
          LogLevel.warning,
          'alerts',
          'a visual alert was requested with no sink registered',
        );
      }
    }
  }

  Future<void> _vibrate(AlertSeverity severity) async {
    try {
      if (await Vibration.hasVibrator()) {
        await Vibration.vibrate(pattern: _patterns[severity]!);
      }
    } on Object catch (error, stackTrace) {
      _logger.log(
        LogLevel.warning,
        'alerts',
        'vibration failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _flashTorch(AlertSeverity severity) async {
    final int pulses = severity == AlertSeverity.critical ? 4 : 2;
    try {
      for (int i = 0; i < pulses; i++) {
        await TorchLight.enableTorch();
        await Future<void>.delayed(const Duration(milliseconds: 180));
        await TorchLight.disableTorch();
        await Future<void>.delayed(const Duration(milliseconds: 120));
      }
    } on Object catch (error, stackTrace) {
      _logger.log(
        LogLevel.warning,
        'alerts',
        'torch alert failed',
        error: error,
        stackTrace: stackTrace,
      );
      try {
        await TorchLight.disableTorch();
      } on Object catch (_) {
        // The torch is already off, or this device has none.
        _logger.log(LogLevel.debug, 'alerts', 'torch was already off');
      }
    }
  }
}
