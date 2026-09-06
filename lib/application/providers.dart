import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:humsukhan/application/account/auth_controller.dart';
import 'package:humsukhan/application/common/operation_state.dart';
import 'package:humsukhan/application/common/retention_sweeper.dart';
import 'package:humsukhan/application/conversation/conversation_session.dart';
import 'package:humsukhan/application/conversation/conversation_session_state.dart';
import 'package:humsukhan/application/environment/monitoring_controller.dart';
import 'package:humsukhan/application/professional/insight_service.dart';
import 'package:humsukhan/application/professional/session_recorder.dart';
import 'package:humsukhan/application/settings/settings_controller.dart';
import 'package:humsukhan/application/speech/speech_setup_controller.dart';
import 'package:humsukhan/core/id/id_generator.dart';
import 'package:humsukhan/core/l10n/app_language.dart';
import 'package:humsukhan/core/l10n/app_strings.dart';
import 'package:humsukhan/core/logging/app_logger.dart';
import 'package:humsukhan/core/theme/app_theme.dart';
import 'package:humsukhan/core/time/clock.dart';
import 'package:humsukhan/domain/account/account.dart';
import 'package:humsukhan/domain/account/auth_port.dart';
import 'package:humsukhan/domain/conversation/conversation_repository_port.dart';
import 'package:humsukhan/domain/conversation/turn_policy.dart';
import 'package:humsukhan/domain/environment/alert_presenter_port.dart';
import 'package:humsukhan/domain/environment/detector_port.dart';
import 'package:humsukhan/domain/environment/model_state.dart';
import 'package:humsukhan/domain/environment/monitoring_service_port.dart';
import 'package:humsukhan/domain/environment/quick_tile_port.dart';
import 'package:humsukhan/domain/environment/sound_event.dart';
import 'package:humsukhan/domain/professional/insight.dart';
import 'package:humsukhan/domain/professional/insight_port.dart';
import 'package:humsukhan/domain/professional/session_repository_port.dart';
import 'package:humsukhan/domain/settings/app_settings.dart';
import 'package:humsukhan/domain/settings/settings_port.dart';
import 'package:humsukhan/domain/speech/capability.dart';
import 'package:humsukhan/domain/speech/language_tag.dart';
import 'package:humsukhan/domain/speech/speech_install_port.dart';
import 'package:humsukhan/domain/speech/stt_port.dart';
import 'package:humsukhan/domain/speech/tts_port.dart';

/// The providers the UI watches.
///
/// Every *port* here is declared and left unimplemented: binding a port to an
/// adapter happens once, in `composition/providers.dart`, which is the only
/// library that imports `infrastructure`. A screen therefore cannot reach an
/// adapter even by accident, and a widget test can override any of these with a
/// fake without touching a plugin.

Never _mustOverride(String name) =>
    throw StateError('$name must be bound in the composition root');

// ---- primitives ---------------------------------------------------------

/// Application logging.
final Provider<AppLogger> loggerProvider = Provider<AppLogger>(
  (Ref ref) => const SilentLogger(),
);

/// The clock everything timestamps against.
final Provider<Clock> clockProvider = Provider<Clock>(
  (Ref ref) => const SystemClock(),
);

/// Identifier generation.
final Provider<IdGenerator> idGeneratorProvider = Provider<IdGenerator>(
  (Ref ref) => TimestampIdGenerator(),
);

// ---- ports --------------------------------------------------------------

/// Accounts and sessions.
final Provider<AuthPort> authPortProvider = Provider<AuthPort>(
  (Ref ref) => _mustOverride('authPortProvider'),
);

/// Session summarisation.
final Provider<InsightPort> insightPortProvider = Provider<InsightPort>(
  (Ref ref) => _mustOverride('insightPortProvider'),
);

/// Where settings are persisted, for the current user.
final Provider<SettingsPort> settingsPortProvider = Provider<SettingsPort>(
  (Ref ref) => _mustOverride('settingsPortProvider'),
);

/// Saved conversations, for the current user.
final Provider<ConversationRepositoryPort> conversationRepositoryProvider =
    Provider<ConversationRepositoryPort>(
      (Ref ref) => _mustOverride('conversationRepositoryProvider'),
    );

/// Professional sessions, for the current user.
final Provider<SessionRepositoryPort> sessionRepositoryProvider =
    Provider<SessionRepositoryPort>(
      (Ref ref) => _mustOverride('sessionRepositoryProvider'),
    );

/// The recogniser Everyday mode uses.
final Provider<SttPort> conversationSttProvider = Provider<SttPort>(
  (Ref ref) => _mustOverride('conversationSttProvider'),
);

/// The recogniser Professional mode uses. Separate, so a live conversation and
/// a live recording never share one transport.
final Provider<SttPort> recorderSttProvider = Provider<SttPort>(
  (Ref ref) => _mustOverride('recorderSttProvider'),
);

/// Speech synthesis.
final Provider<TtsPort> ttsPortProvider = Provider<TtsPort>(
  (Ref ref) => _mustOverride('ttsPortProvider'),
);

/// What this device can recognise and speak.
final Provider<SpeechCapabilityPort> capabilityProvider =
    Provider<SpeechCapabilityPort>(
      (Ref ref) => _mustOverride('capabilityProvider'),
    );

/// Installs speech language packs using the device's own machinery.
final Provider<SpeechInstallPort> speechInstallProvider =
    Provider<SpeechInstallPort>(
      (Ref ref) => _mustOverride('speechInstallProvider'),
    );

/// On-device sound detection.
final Provider<SoundDetectorPort> detectorProvider =
    Provider<SoundDetectorPort>((Ref ref) => _mustOverride('detectorProvider'));

/// The on-device sound model.
final Provider<ModelRepositoryPort> modelRepositoryProvider =
    Provider<ModelRepositoryPort>(
      (Ref ref) => _mustOverride('modelRepositoryProvider'),
    );

/// Keeps the process alive while monitoring runs.
final Provider<MonitoringServicePort> monitoringServiceProvider =
    Provider<MonitoringServicePort>(
      (Ref ref) => _mustOverride('monitoringServiceProvider'),
    );

/// The Quick Settings tile.
final Provider<QuickTilePort> quickTileProvider = Provider<QuickTilePort>(
  (Ref ref) => _mustOverride('quickTileProvider'),
);

/// How alerts reach the user.
final Provider<AlertPresenterPort> alertPresenterProvider =
    Provider<AlertPresenterPort>(
      (Ref ref) => _mustOverride('alertPresenterProvider'),
    );

/// A screen-level sink for visual alerts, filled by the alert presenter.
final Provider<StreamController<SoundEvent>> visualAlertsProvider =
    Provider<StreamController<SoundEvent>>((Ref ref) {
      // ignore: close_sinks — closed by the ref.onDispose immediately below.
      final StreamController<SoundEvent> controller =
          StreamController<SoundEvent>.broadcast();
      ref.onDispose(controller.close);
      return controller;
    });

// ---- account ------------------------------------------------------------

/// The signed-in account and the gate's phase.
final NotifierProvider<AuthNotifier, AuthState> authControllerProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

/// Mirrors [AuthController] into Riverpod.
final class AuthNotifier extends Notifier<AuthState> {
  AuthController? _controller;

  /// The controller, for commands.
  AuthController get controller => _controller!;

  @override
  AuthState build() {
    final AuthController controller = AuthController(
      port: ref.watch(authPortProvider),
      logger: ref.watch(loggerProvider),
    );
    _controller = controller;
    final StreamSubscription<AuthState> subscription = controller.states.listen(
      (AuthState next) => state = next,
    );
    ref.onDispose(() {
      unawaited(subscription.cancel());
      unawaited(controller.dispose());
    });
    unawaited(controller.initialise());
    return controller.state;
  }
}

/// Who is signed in, if anyone.
final Provider<Account?> accountProvider = Provider<Account?>(
  (Ref ref) => ref.watch(authControllerProvider).account,
);

// ---- settings -----------------------------------------------------------

/// The user's choices, as an idle/loading/success/failure state.
final NotifierProvider<SettingsNotifier, OperationState<AppSettings>>
settingsControllerProvider =
    NotifierProvider<SettingsNotifier, OperationState<AppSettings>>(
      SettingsNotifier.new,
    );

/// Mirrors [SettingsController] into Riverpod.
final class SettingsNotifier extends Notifier<OperationState<AppSettings>> {
  SettingsController? _controller;

  /// The controller, for commands.
  SettingsController get controller => _controller!;

  @override
  OperationState<AppSettings> build() {
    final SettingsController controller = SettingsController(
      port: ref.watch(settingsPortProvider),
    );
    _controller = controller;
    final StreamSubscription<OperationState<AppSettings>> subscription =
        controller.states.listen(
          (OperationState<AppSettings> next) => state = next,
        );
    ref.onDispose(() {
      unawaited(subscription.cancel());
      unawaited(controller.dispose());
    });
    unawaited(controller.load());
    return controller.state;
  }
}

/// The settings in force, with defaults until the load finishes.
final Provider<AppSettings> settingsProvider = Provider<AppSettings>(
  (Ref ref) =>
      ref.watch(settingsControllerProvider).valueOrNull ?? const AppSettings(),
);

/// The guided "this language needs a download" flow.
///
/// Every feature that needs speech routes through this rather than checking
/// capability itself, so a screen cannot forget the check and present a control
/// that silently does nothing.
final NotifierProvider<SpeechSetupNotifier, SpeechSetupState>
speechSetupProvider = NotifierProvider<SpeechSetupNotifier, SpeechSetupState>(
  SpeechSetupNotifier.new,
);

/// Mirrors [SpeechSetupController] into Riverpod.
final class SpeechSetupNotifier extends Notifier<SpeechSetupState> {
  SpeechSetupController? _controller;

  /// The controller, for commands.
  SpeechSetupController get controller => _controller!;

  @override
  SpeechSetupState build() {
    final SpeechSetupController controller = SpeechSetupController(
      capability: ref.watch(capabilityProvider),
      installer: ref.watch(speechInstallProvider),
      logger: ref.watch(loggerProvider),
    );
    _controller = controller;
    final StreamSubscription<SpeechSetupState> subscription = controller.states
        .listen((SpeechSetupState next) => state = next);
    ref.onDispose(() {
      unawaited(subscription.cancel());
      unawaited(controller.dispose());
    });
    return controller.state;
  }
}

/// The interface language.
final Provider<AppLanguage> appLanguageProvider = Provider<AppLanguage>(
  (Ref ref) => ref.watch(settingsProvider).appLanguage,
);

/// Localised copy for the current language.
final Provider<AppStrings> stringsProvider = Provider<AppStrings>(
  (Ref ref) => AppStrings.of(ref.watch(appLanguageProvider)),
);

/// The pause rule in force.
final Provider<PauseThreshold> pauseThresholdProvider =
    Provider<PauseThreshold>(
      (Ref ref) => ref.watch(settingsProvider).pauseThreshold,
    );

/// The recognition language in force.
final Provider<LanguageTag> captionLanguageProvider = Provider<LanguageTag>(
  (Ref ref) => ref.watch(settingsProvider).captionLanguage,
);

/// The alert channels in force.
final Provider<AlertChannels> alertChannelsProvider = Provider<AlertChannels>(
  (Ref ref) => ref.watch(settingsProvider).alertChannels,
);

/// Which of the three themes is in force.
final Provider<AppThemeVariant> themeVariantProvider =
    Provider<AppThemeVariant>((Ref ref) {
      final AppSettings settings = ref.watch(settingsProvider);
      // High contrast is its own theme and wins over dark mode; it is not a
      // filter layered over another palette.
      if (settings.highContrast) return AppThemeVariant.highContrast;
      return settings.darkMode ? AppThemeVariant.dark : AppThemeVariant.light;
    });

/// Whether this device can speak each language.
///
/// Asked, and shown, rather than discovered when the user taps Speak: "no Urdu
/// voice on this device" is worth knowing before you rely on it
/// (docs/instructions.md §1.3).
final FutureProvider<Map<LanguageTag, Capability>> voiceCapabilityProvider =
    FutureProvider<Map<LanguageTag, Capability>>((Ref ref) async {
      final SpeechCapabilityPort port = ref.watch(capabilityProvider);
      return <LanguageTag, Capability>{
        for (final LanguageTag tag in LanguageTag.values)
          tag: await port.tts(tag),
      };
    });

/// Deletes anything past its retention window.
final Provider<RetentionSweeper> retentionSweeperProvider =
    Provider<RetentionSweeper>(
      (Ref ref) => RetentionSweeper(
        conversations: ref.watch(conversationRepositoryProvider),
        sessions: ref.watch(sessionRepositoryProvider),
        clock: ref.watch(clockProvider),
        logger: ref.watch(loggerProvider),
      ),
    );

// ---- conversation -------------------------------------------------------

/// The Everyday session.
final NotifierProvider<ConversationNotifier, ConversationSessionState>
conversationProvider =
    NotifierProvider<ConversationNotifier, ConversationSessionState>(
      ConversationNotifier.new,
    );

/// Mirrors [ConversationSession] into Riverpod.
final class ConversationNotifier extends Notifier<ConversationSessionState> {
  ConversationSession? _session;

  /// The session, for commands.
  ConversationSession get session => _session!;

  @override
  ConversationSessionState build() {
    // Settings are *read*, not watched. Watching them would rebuild this
    // notifier — disposing the live session — every time the user changed the
    // theme or any other preference. A conversation in progress must survive
    // every setting change, so the two values the session cares about are
    // pushed into it below instead.
    final AppSettings settings = ref.read(settingsProvider);
    final ConversationSession session = ConversationSession(
      stt: ref.watch(conversationSttProvider),
      tts: ref.watch(ttsPortProvider),
      ids: ref.watch(idGeneratorProvider),
      clock: ref.watch(clockProvider),
      captionLanguage: settings.captionLanguage,
      threshold: settings.pauseThreshold,
      logger: ref.watch(loggerProvider),
    )..bindTtsActivity();
    _session = session;

    ref.listen<PauseThreshold>(
      pauseThresholdProvider,
      (PauseThreshold? _, PauseThreshold next) => session.setThreshold(next),
    );
    ref.listen<LanguageTag>(
      captionLanguageProvider,
      (LanguageTag? _, LanguageTag next) => session.setCaptionLanguage(next),
    );

    final StreamSubscription<ConversationSessionState> subscription = session
        .states
        .listen((ConversationSessionState next) => state = next);
    ref.onDispose(() {
      unawaited(subscription.cancel());
      unawaited(session.dispose());
    });
    return session.state;
  }
}

// ---- professional -------------------------------------------------------

/// The live Professional recording.
final NotifierProvider<RecorderNotifier, RecorderState> recorderProvider =
    NotifierProvider<RecorderNotifier, RecorderState>(RecorderNotifier.new);

/// Mirrors [SessionRecorder] into Riverpod.
final class RecorderNotifier extends Notifier<RecorderState> {
  SessionRecorder? _recorder;

  /// The recorder, for commands.
  SessionRecorder get recorder => _recorder!;

  @override
  RecorderState build() {
    final SessionRecorder recorder = SessionRecorder(
      stt: ref.watch(recorderSttProvider),
      ids: ref.watch(idGeneratorProvider),
      clock: ref.watch(clockProvider),
      logger: ref.watch(loggerProvider),
    );
    _recorder = recorder;
    final StreamSubscription<RecorderState> subscription = recorder.states
        .listen((RecorderState next) => state = next);
    ref.onDispose(() {
      unawaited(subscription.cancel());
      unawaited(recorder.dispose());
    });
    return recorder.state;
  }
}

/// Summarisation state for the session on screen.
final NotifierProvider<InsightNotifier, OperationState<Insight>>
insightServiceProvider =
    NotifierProvider<InsightNotifier, OperationState<Insight>>(
      InsightNotifier.new,
    );

/// Mirrors [InsightService] into Riverpod.
final class InsightNotifier extends Notifier<OperationState<Insight>> {
  InsightService? _service;

  /// The service, for commands.
  InsightService get service => _service!;

  @override
  OperationState<Insight> build() {
    final InsightService service = InsightService(
      port: ref.watch(insightPortProvider),
    );
    _service = service;
    final StreamSubscription<OperationState<Insight>> subscription = service
        .states
        .listen((OperationState<Insight> next) => state = next);
    ref.onDispose(() {
      unawaited(subscription.cancel());
      unawaited(service.dispose());
    });
    return service.state;
  }
}

// ---- environment --------------------------------------------------------

/// Environmental monitoring.
final NotifierProvider<MonitoringNotifier, MonitoringState> monitoringProvider =
    NotifierProvider<MonitoringNotifier, MonitoringState>(
      MonitoringNotifier.new,
    );

/// Mirrors [MonitoringController] into Riverpod.
final class MonitoringNotifier extends Notifier<MonitoringState> {
  MonitoringController? _controller;

  /// The controller, for commands.
  MonitoringController get controller => _controller!;

  @override
  MonitoringState build() {
    final MonitoringController controller = MonitoringController(
      detector: ref.watch(detectorProvider),
      models: ref.watch(modelRepositoryProvider),
      presenter: ref.watch(alertPresenterProvider),
      ids: ref.watch(idGeneratorProvider),
      clock: ref.watch(clockProvider),
      logger: ref.watch(loggerProvider),
    )..setChannels(ref.read(alertChannelsProvider));
    _controller = controller;

    // Same reasoning as the conversation session: watching settings here would
    // tear down a running monitor the moment any setting changed — including
    // the "monitoring enabled" flag the toggle itself writes, which made the
    // toggle appear to do nothing at all.
    ref.listen<AlertChannels>(
      alertChannelsProvider,
      (AlertChannels? _, AlertChannels next) => controller.setChannels(next),
    );

    final StreamSubscription<MonitoringState> subscription = controller.states
        .listen((MonitoringState next) => state = next);
    ref.onDispose(() {
      unawaited(subscription.cancel());
      unawaited(controller.dispose());
    });
    return controller.state;
  }
}
