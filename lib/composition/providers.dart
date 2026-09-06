import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/widgets.dart'
    show BuildContext, StatelessWidget, Widget;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:humsukhan/application/providers.dart';
import 'package:humsukhan/composition/model_artefacts.dart';
import 'package:humsukhan/composition/unavailable_adapters.dart';
import 'package:humsukhan/core/env/app_config.dart';
import 'package:humsukhan/core/logging/app_logger.dart';
import 'package:humsukhan/domain/account/account.dart';
import 'package:humsukhan/domain/environment/sound_event.dart';
import 'package:humsukhan/infrastructure/audio/microphone_source.dart';
import 'package:humsukhan/infrastructure/backend/backend_gateway.dart';
import 'package:humsukhan/infrastructure/backend/device_auth_adapter.dart';
import 'package:humsukhan/infrastructure/backend/edge_insight_adapter.dart';
import 'package:humsukhan/infrastructure/backend/supabase_auth_adapter.dart';
import 'package:humsukhan/infrastructure/backend/supabase_gateway.dart';
import 'package:humsukhan/infrastructure/environment/alert_presenter.dart';
import 'package:humsukhan/infrastructure/environment/monitoring_service.dart';
import 'package:humsukhan/infrastructure/environment/quick_tile_channel.dart';
import 'package:humsukhan/infrastructure/environment/sherpa_sound_detector.dart';
import 'package:humsukhan/infrastructure/model/model_repository.dart';
import 'package:humsukhan/infrastructure/storage/key_value_store.dart';
import 'package:humsukhan/infrastructure/storage/local_repositories.dart';
import 'package:humsukhan/infrastructure/storage/prefs_settings_store.dart';
import 'package:humsukhan/infrastructure/storage/user_scope.dart';
import 'package:humsukhan/infrastructure/speech/platform_speech_installer.dart';
import 'package:humsukhan/infrastructure/stt/deepgram_stt_adapter.dart';
import 'package:humsukhan/infrastructure/stt/fallback_stt_adapter.dart';
import 'package:humsukhan/infrastructure/stt/native_stt_adapter.dart';
import 'package:humsukhan/infrastructure/stt/platform_recogniser.dart';
import 'package:humsukhan/infrastructure/stt/recognition_token.dart';
import 'package:humsukhan/infrastructure/tts/cloud_tts_adapter.dart';
import 'package:humsukhan/infrastructure/tts/fallback_tts_adapter.dart';
import 'package:humsukhan/infrastructure/tts/native_tts_adapter.dart';
import 'package:humsukhan/infrastructure/tts/speech_capability_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

/// The composition root: the only library that knows both a port and its
/// adapter.
///
/// `application/providers.dart` declares the ports the UI watches; this file
/// binds each one. The layering test keeps `features` from importing anything
/// under `infrastructure`, so a screen physically cannot reach an adapter.

// ---- boot-time values ---------------------------------------------------

/// Build configuration. Overridden in `main`.
final Provider<AppConfig> appConfigProvider = Provider<AppConfig>(
  (Ref ref) => throw StateError('appConfigProvider must be overridden at boot'),
);

/// The platform key-value store. Overridden in `main`.
final Provider<KeyValueStore> keyValueStoreProvider = Provider<KeyValueStore>(
  (Ref ref) =>
      throw StateError('keyValueStoreProvider must be overridden at boot'),
);

/// The Supabase client, or `null` when this build has no backend.
final Provider<SupabaseClient?> supabaseClientProvider =
    Provider<SupabaseClient?>((Ref ref) => null);

/// Where the on-device model is installed. Overridden in `main`.
final Provider<Directory> modelDirectoryProvider = Provider<Directory>(
  (Ref ref) =>
      throw StateError('modelDirectoryProvider must be overridden at boot'),
);

// ---- derived infrastructure --------------------------------------------

/// Edge Function access, or `null` when there is no backend.
final Provider<BackendGateway?> backendGatewayProvider =
    Provider<BackendGateway?>((Ref ref) {
      final SupabaseClient? client = ref.watch(supabaseClientProvider);
      if (client == null) return null;
      return SupabaseGateway(client: client, logger: ref.watch(loggerProvider));
    });

/// The namespace every per-user store writes under.
///
/// Watched by each per-user binding, so switching account rebuilds those
/// providers rather than carrying one user's data into another's session.
final Provider<UserScope> userScopeProvider = Provider<UserScope>((Ref ref) {
  final Account? account = ref.watch(accountProvider);
  return account == null ? UserScope.anonymous : UserScope(account.id);
});

/// The microphone, shared by recognition and monitoring.
final Provider<MicrophoneSource> microphoneProvider =
    Provider<MicrophoneSource>((Ref ref) {
      final RecordMicrophoneSource source = RecordMicrophoneSource(
        logger: ref.watch(loggerProvider),
      );
      ref.onDispose(source.dispose);
      return source;
    });

/// Short-lived recognition credentials.
final Provider<RecognitionTokenSource> tokenSourceProvider =
    Provider<RecognitionTokenSource>((Ref ref) {
      final BackendGateway? gateway = ref.watch(backendGatewayProvider);
      if (gateway == null) return const UnavailableTokenSource();
      return BackendTokenSource(
        gateway: gateway,
        functionName: ref.watch(appConfigProvider).tokenFunction,
      );
    });

/// The platform speech engine.
final Provider<NativeTtsAdapter> nativeTtsProvider = Provider<NativeTtsAdapter>(
  (Ref ref) {
    final NativeTtsAdapter adapter = NativeTtsAdapter(
      logger: ref.watch(loggerProvider),
    );
    ref.onDispose(adapter.dispose);
    return adapter;
  },
);

/// The device recogniser.
///
/// Shared between the conversation recogniser and the capability probe so both
/// answer from one engine: a probe that consults a different instance than the
/// one that will actually listen can disagree with it, and the user would be
/// told a language works that then does not.
final Provider<NativeSttAdapter> nativeSttProvider = Provider<NativeSttAdapter>(
  (Ref ref) {
    final NativeSttAdapter adapter = NativeSttAdapter(
      recogniser: SpeechToTextRecogniser(logger: ref.watch(loggerProvider)),
      permissions: ref.watch(microphoneProvider),
      logger: ref.watch(loggerProvider),
    );
    ref.onDispose(adapter.dispose);
    return adapter;
  },
);

/// The server recogniser, when this build has a backend to reach.
///
/// Returns `null` on a stock install, which is the ordinary case: the app
/// recognises on the device and needs nothing configured to do it.
DeepgramSttAdapter? _serverRecogniser(Ref ref, {int maxReconnectAttempts = 5}) {
  if (ref.watch(backendGatewayProvider) == null) return null;
  return DeepgramSttAdapter(
    microphone: ref.watch(microphoneProvider),
    tokens: ref.watch(tokenSourceProvider),
    logger: ref.watch(loggerProvider),
    maxReconnectAttempts: maxReconnectAttempts,
  );
}

/// The audio tagger, shared by the readiness probe and the detector so the
/// model is loaded exactly once.
final Provider<SherpaAudioTagger> audioTaggerProvider =
    Provider<SherpaAudioTagger>((Ref ref) {
      final SherpaAudioTagger tagger = SherpaAudioTagger(
        logger: ref.watch(loggerProvider),
      );
      ref.onDispose(tagger.release);
      return tagger;
    });

/// A [ProviderScope] with every declared port bound to its adapter.
///
/// Riverpod does not export the type of an override, so the bindings are a
/// widget rather than a list. Tests that want a fake nest their own
/// `ProviderScope` inside this one, or build a scope of their own.
class HumSukhanScope extends StatelessWidget {
  /// Wraps [child] in the fully bound container.
  const HumSukhanScope({
    required this.config,
    required this.store,
    required this.modelDirectory,
    required this.child,
    super.key,
    this.client,
  });

  /// Build configuration.
  final AppConfig config;

  /// The platform key-value store.
  final KeyValueStore store;

  /// Where the on-device model is installed.
  final Directory modelDirectory;

  /// The backend client, or `null` when this build has none.
  final SupabaseClient? client;

  /// The app.
  final Widget child;

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [
      appConfigProvider.overrideWithValue(config),
      keyValueStoreProvider.overrideWithValue(store),
      supabaseClientProvider.overrideWithValue(client),
      modelDirectoryProvider.overrideWithValue(modelDirectory),
      loggerProvider.overrideWith(
        (Ref ref) => kReleaseMode
            ? const DeveloperLogger(minimum: LogLevel.warning)
            : const DeveloperLogger(),
      ),

      authPortProvider.overrideWith((Ref ref) {
        final SupabaseClient? client = ref.watch(supabaseClientProvider);
        if (client == null) {
          // No server to sign in to. The app runs on a device account rather
          // than showing a sign-in screen no password can pass — an
          // accessibility tool that cannot be opened is the worst outcome
          // available here.
          final DeviceAuthAdapter port = DeviceAuthAdapter(
            store: ref.watch(keyValueStoreProvider),
            ids: ref.watch(idGeneratorProvider),
            logger: ref.watch(loggerProvider),
          );
          ref.onDispose(port.dispose);
          return port;
        }
        final SupabaseAuthAdapter adapter = SupabaseAuthAdapter(
          client: client,
          logger: ref.watch(loggerProvider),
        );
        ref.onDispose(adapter.dispose);
        return adapter;
      }),

      insightPortProvider.overrideWith((Ref ref) {
        final BackendGateway? gateway = ref.watch(backendGatewayProvider);
        if (gateway == null) return const UnavailableInsightPort();
        return EdgeInsightAdapter(
          gateway: gateway,
          functionName: ref.watch(appConfigProvider).summariseFunction,
        );
      }),

      settingsPortProvider.overrideWith(
        (Ref ref) => PrefsSettingsStore(
          store: ref.watch(keyValueStoreProvider),
          scope: ref.watch(userScopeProvider),
          logger: ref.watch(loggerProvider),
        ),
      ),

      conversationRepositoryProvider.overrideWith(
        (Ref ref) => LocalConversationRepository(
          store: ref.watch(keyValueStoreProvider),
          scope: ref.watch(userScopeProvider),
          logger: ref.watch(loggerProvider),
        ),
      ),

      sessionRepositoryProvider.overrideWith(
        (Ref ref) => LocalSessionRepository(
          store: ref.watch(keyValueStoreProvider),
          scope: ref.watch(userScopeProvider),
          logger: ref.watch(loggerProvider),
        ),
      ),

      conversationSttProvider.overrideWith((Ref ref) {
        final FallbackSttAdapter adapter = FallbackSttAdapter(
          primary: ref.watch(nativeSttProvider),
          fallback: _serverRecogniser(ref),
          logger: ref.watch(loggerProvider),
        );
        ref.onDispose(adapter.dispose);
        return adapter;
      }),

      recorderSttProvider.overrideWith((Ref ref) {
        final FallbackSttAdapter adapter = FallbackSttAdapter(
          primary: NativeSttAdapter(
            recogniser: SpeechToTextRecogniser(
              logger: ref.watch(loggerProvider),
            ),
            permissions: ref.watch(microphoneProvider),
            logger: ref.watch(loggerProvider),
            // A lecture is long and a device recogniser is chatty about it.
            // A larger budget keeps an hour-long session alive through the
            // occasional bad segment.
            maxConsecutiveFailures: 8,
          ),
          fallback: _serverRecogniser(ref, maxReconnectAttempts: 8),
          logger: ref.watch(loggerProvider),
        );
        ref.onDispose(adapter.dispose);
        return adapter;
      }),

      ttsPortProvider.overrideWith((Ref ref) {
        final BackendGateway? gateway = ref.watch(backendGatewayProvider);
        final FallbackTtsAdapter adapter = FallbackTtsAdapter(
          primary: ref.watch(nativeTtsProvider),
          fallback: gateway == null
              ? null
              : CloudTtsAdapter(
                  gateway: gateway,
                  functionName: ref.watch(appConfigProvider).cloudTtsFunction,
                  logger: ref.watch(loggerProvider),
                ),
          logger: ref.watch(loggerProvider),
        );
        ref.onDispose(adapter.dispose);
        return adapter;
      }),

      capabilityProvider.overrideWith(
        (Ref ref) => SpeechCapabilityService(
          voices: ref.watch(nativeTtsProvider),
          recognisers: ref.watch(nativeSttProvider),
          hasCloudFallback: ref.watch(backendGatewayProvider) != null,
          hasRecognitionBackend: ref.watch(backendGatewayProvider) != null,
          clock: ref.watch(clockProvider),
          logger: ref.watch(loggerProvider),
        ),
      ),

      speechInstallProvider.overrideWith(
        (Ref ref) => PlatformSpeechInstaller(
          capability: ref.watch(capabilityProvider),
          logger: ref.watch(loggerProvider),
        ),
      ),

      modelRepositoryProvider.overrideWith((Ref ref) {
        final SherpaAudioTagger tagger = ref.watch(audioTaggerProvider);
        final BundledModelRepository repository = BundledModelRepository(
          installDirectory: ref.watch(modelDirectoryProvider),
          model: ModelArtefacts.cedTinyModel,
          labels: ModelArtefacts.cedTinyLabels,
          // Readiness is decided by an actual load, not by two files existing.
          probe: (String modelPath, String labelsPath) =>
              tagger.load(modelPath: modelPath, labelsPath: labelsPath),
          logger: ref.watch(loggerProvider),
        );
        ref.onDispose(repository.dispose);
        return repository;
      }),

      detectorProvider.overrideWith((Ref ref) {
        final SherpaSoundDetector detector = SherpaSoundDetector(
          microphone: ref.watch(microphoneProvider),
          models: ref.watch(modelRepositoryProvider),
          tagger: ref.watch(audioTaggerProvider),
          logger: ref.watch(loggerProvider),
        );
        ref.onDispose(detector.dispose);
        return detector;
      }),

      monitoringServiceProvider.overrideWith(
        (Ref ref) =>
            ForegroundMonitoringService(logger: ref.watch(loggerProvider)),
      ),

      quickTileProvider.overrideWith((Ref ref) {
        final QuickTileChannel channel = QuickTileChannel(
          logger: ref.watch(loggerProvider),
        );
        ref.onDispose(channel.dispose);
        return channel;
      }),

      alertPresenterProvider.overrideWith((Ref ref) {
        // ignore: close_sinks — owned and closed by visualAlertsProvider.
        final StreamController<SoundEvent> sink = ref.watch(
          visualAlertsProvider,
        );
        return DeviceAlertPresenter(
          onVisual: (SoundEvent event) {
            if (!sink.isClosed) sink.add(event);
          },
          logger: ref.watch(loggerProvider),
        );
      }),
    ],
    child: child,
  );
}
