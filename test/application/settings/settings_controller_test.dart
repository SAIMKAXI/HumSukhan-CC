import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/application/common/async_state.dart';
import 'package:humsukhan/application/settings/settings_controller.dart';
import 'package:humsukhan/core/failure/failure.dart';
import 'package:humsukhan/core/l10n/app_language.dart';
import 'package:humsukhan/core/result/result.dart';
import 'package:humsukhan/domain/conversation/conversation_repository_port.dart';
import 'package:humsukhan/domain/conversation/turn_policy.dart';
import 'package:humsukhan/domain/professional/retention_policy.dart';
import 'package:humsukhan/domain/settings/app_settings.dart';

import '../../fakes/fake_app_ports.dart';

void main() {
  late FakeSettingsPort port;
  late SettingsController controller;

  setUp(() {
    port = FakeSettingsPort();
    controller = SettingsController(port: port);
  });

  tearDown(() async => controller.dispose());

  test('load moves idle to success', () async {
    expect(controller.state, isA<AsyncIdle<AppSettings>>());
    await controller.load();
    expect(controller.state, isA<AsyncSuccess<AppSettings>>());
  });

  test('a load failure is a failure state, not silent defaults', () async {
    port.failOnLoad = const StorageFailure(FailureCode.storageReadFailed);
    await controller.load();

    expect(controller.state, isA<AsyncFailure<AppSettings>>());
    expect(controller.settings, const AppSettings());
  });

  test('a change is persisted', () async {
    await controller.load();
    await controller.setAppLanguage(AppLanguage.urdu);

    expect(port.saves.last.appLanguage, AppLanguage.urdu);
    expect(controller.settings.appLanguage, AppLanguage.urdu);
  });

  test('a save failure is reported to the caller', () async {
    await controller.load();
    port.failOnSave = const StorageFailure(FailureCode.storageWriteFailed);

    final Result<Unit, StorageFailure> result = await controller.setDarkMode(
      true,
    );

    expect(result.isErr, isTrue);
  });

  test('retention is clamped to the product maximum on the way in', () async {
    await controller.load();
    await controller.setRetentionDays(365);

    expect(controller.settings.retentionDays, RetentionPolicy.maximumDays);
  });

  test('large text multiplies rather than replacing the OS scale', () async {
    await controller.load();
    expect(controller.settings.textScaleMultiplier, 1.0);

    await controller.setLargeText(true);
    expect(controller.settings.textScaleMultiplier, 1.2);
  });

  test('the pause threshold round-trips', () async {
    await controller.load();
    await controller.setPauseThreshold(PauseThreshold.patient);

    expect(controller.settings.pauseThreshold, PauseThreshold.patient);
  });

  test('alert channels round-trip', () async {
    await controller.load();
    await controller.setAlertChannels(
      const AlertChannels(haptic: false, torch: true),
    );

    expect(controller.settings.alertChannels.torch, isTrue);
    expect(controller.settings.alertChannels.haptic, isFalse);
  });

  test('a selection with no channel at all is detectable', () {
    const AlertChannels none = AlertChannels(
      haptic: false,
      visual: false,
      screenFlash: false,
    );
    expect(none.hasAny, isFalse);
  });
}
