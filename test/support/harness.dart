import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/application/providers.dart';
import 'package:humsukhan/core/l10n/app_language.dart';
import 'package:humsukhan/core/l10n/app_strings.dart';
import 'package:humsukhan/core/result/result.dart';
import 'package:humsukhan/core/theme/app_theme.dart';
import 'package:humsukhan/domain/environment/alert_presenter_port.dart';
import 'package:humsukhan/domain/environment/detector_port.dart';
import 'package:humsukhan/domain/environment/monitoring_service_port.dart';
import 'package:humsukhan/domain/environment/quick_tile_port.dart';
import 'package:humsukhan/domain/settings/app_settings.dart';

import '../fakes/fake_app_ports.dart';
import '../fakes/fake_speech_ports.dart';

/// Wraps [child] with every port bound to a fake.
///
/// This is what makes the UI testable on a machine with no device: a widget
/// test cannot reach a plugin, because no adapter is in the graph.
Widget harness({
  required Widget child,
  AppLanguage language = AppLanguage.english,
  AppThemeVariant variant = AppThemeVariant.light,
  AppSettings? settings,
  FakeSttPort? conversationStt,
  FakeSttPort? recorderStt,
  FakeTtsPort? tts,
  FakeInsightPort? insight,
  FakeSoundDetector? detector,
  FakeModelRepository? models,
  FakeAuthPort? auth,
  FakeSettingsPort? settingsPort,
  FakeConversationRepository? conversations,
  FakeSessionRepository? sessions,
  AlertPresenterPort? presenter,
}) {
  final AppSettings initial = (settings ?? const AppSettings()).copyWith(
    appLanguage: language,
  );
  return ProviderScope(
    overrides: [
      settingsPortProvider.overrideWithValue(
        settingsPort ?? FakeSettingsPort(initial: initial),
      ),
      authPortProvider.overrideWithValue(auth ?? FakeAuthPort()),
      insightPortProvider.overrideWithValue(insight ?? FakeInsightPort()),
      conversationSttProvider.overrideWithValue(
        conversationStt ?? FakeSttPort(),
      ),
      recorderSttProvider.overrideWithValue(recorderStt ?? FakeSttPort()),
      ttsPortProvider.overrideWithValue(tts ?? FakeTtsPort()),
      detectorProvider.overrideWithValue(detector ?? FakeSoundDetector()),
      modelRepositoryProvider.overrideWithValue(
        models ?? FakeModelRepository(),
      ),
      alertPresenterProvider.overrideWithValue(
        presenter ?? RecordingAlertPresenter(),
      ),
      monitoringServiceProvider.overrideWithValue(
        const NoopMonitoringService(),
      ),
      quickTileProvider.overrideWithValue(const NoopQuickTile()),
      conversationRepositoryProvider.overrideWithValue(
        conversations ?? FakeConversationRepository(),
      ),
      sessionRepositoryProvider.overrideWithValue(
        sessions ?? FakeSessionRepository(),
      ),
      idGeneratorProvider.overrideWithValue(FakeIdGenerator()),
      clockProvider.overrideWithValue(FakeClock()),
    ],
    child: MaterialApp(
      locale: language.locale,
      theme: AppTheme.build(variant, language),
      home: Directionality(textDirection: language.direction, child: child),
    ),
  );
}

/// The English copy, for asserting on what a screen shows.
final AppStrings english = AppStrings.of(AppLanguage.english);

/// The Urdu copy.
final AppStrings urdu = AppStrings.of(AppLanguage.urdu);

/// Lets provider initialisation settle without pumping a live session's timers
/// to completion.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(Duration.zero);
}

/// A foreground service that does nothing, for tests.
final class NoopMonitoringService implements MonitoringServicePort {
  /// Creates the service.
  const NoopMonitoringService();

  @override
  Future<Result<Unit, DetectorFailure>> start({
    required String title,
    required String body,
  }) async => const Ok<Unit, DetectorFailure>(unit);

  @override
  Future<void> stop() async {}

  @override
  Future<bool> isRunning() async => false;
}

/// A Quick Settings tile that never fires, for tests.
final class NoopQuickTile implements QuickTilePort {
  /// Creates the tile.
  const NoopQuickTile();

  @override
  Future<bool> consumePendingRequest() async => false;

  @override
  Stream<void> get requests => const Stream<void>.empty();

  @override
  Future<void> publishActive({required bool active}) async {}
}
