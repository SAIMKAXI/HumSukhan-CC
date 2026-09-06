import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:humsukhan/application/providers.dart';
import 'package:humsukhan/application/environment/monitoring_controller.dart';
import 'package:humsukhan/core/l10n/app_strings.dart';
import 'package:humsukhan/core/logging/app_logger.dart';
import 'package:humsukhan/composition/shell/alert_overlay.dart';
import 'package:humsukhan/features/conversation/conversation_screen.dart';
import 'package:humsukhan/features/environment/environment_screen.dart';
import 'package:humsukhan/features/home/home_screen.dart';
import 'package:humsukhan/features/professional/professional_screen.dart';
import 'package:humsukhan/features/settings/settings_screen.dart';

/// The five destinations, over an [IndexedStack].
///
/// An IndexedStack rather than a page swap, because a live conversation or
/// recording must survive a tab change (docs/instructions.md §4).
class MainScaffold extends ConsumerStatefulWidget {
  /// Creates the scaffold.
  const MainScaffold({super.key});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  int _index = 0;
  StreamSubscription<void>? _tileRequests;

  @override
  void initState() {
    super.initState();
    // The Quick Settings tile hands its request here rather than touching the
    // microphone itself, so there is one owner of monitoring and one place that
    // can explain a failure to start.
    unawaited(_consumeTileRequest());
    _tileRequests = ref
        .read(quickTileProvider)
        .requests
        .listen(
          (void _) => unawaited(_handleTileRequest()),
          onError: (Object error, StackTrace stackTrace) => ref
              .read(loggerProvider)
              .log(
                LogLevel.warning,
                'tile',
                'tile request stream error',
                error: error,
                stackTrace: stackTrace,
              ),
        );
  }

  @override
  void dispose() {
    unawaited(_tileRequests?.cancel());
    super.dispose();
  }

  Future<void> _consumeTileRequest() async {
    final bool requested = await ref
        .read(quickTileProvider)
        .consumePendingRequest();
    if (!requested) return;
    await _handleTileRequest();
  }

  Future<void> _handleTileRequest() async {
    // Liveness check before touching state.
    if (!mounted) return;
    _select(MainTab.alerts);
    final bool running = ref.read(monitoringProvider).isRunning;
    final AppStrings strings = ref.read(stringsProvider);
    final MonitoringController controller = ref
        .read(monitoringProvider.notifier)
        .controller;
    if (running) {
      await controller.stop();
    } else {
      await controller.start(
        notificationTitle: strings(StringKey.envNotificationTitle),
        notificationBody: strings(StringKey.envNotificationBody),
      );
    }
    if (!mounted) return;
    await ref
        .read(settingsControllerProvider.notifier)
        .controller
        .setMonitoringEnabled(!running);
  }

  void _select(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = ref.watch(stringsProvider);

    // A Column rather than an outer Scaffold: each screen brings its own
    // Scaffold, and nesting one inside another leaves the inner screen's
    // floating action button, bottom sheets and snack bars layered under the
    // shell — a control that renders and cannot be tapped.
    return AlertOverlay(
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        child: Column(
          children: <Widget>[
            Expanded(
              child: IndexedStack(
                index: _index,
                children: <Widget>[
                  // Each tab gets its own messenger. A single messenger serves
                  // every Scaffold registered with it, and all five tabs stay
                  // mounted in this stack — so one snack bar would be shown
                  // five times over, colliding on its own Hero tag.
                  ScaffoldMessenger(child: HomeScreen(onOpenTab: _select)),
                  const ScaffoldMessenger(child: ConversationScreen()),
                  const ScaffoldMessenger(child: ProfessionalScreen()),
                  const ScaffoldMessenger(child: EnvironmentScreen()),
                  const ScaffoldMessenger(child: SettingsScreen()),
                ],
              ),
            ),
            NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: _select,
              destinations: <NavigationDestination>[
                NavigationDestination(
                  icon: const Icon(Icons.home_outlined),
                  selectedIcon: const Icon(Icons.home),
                  label: strings(StringKey.navHome),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.forum_outlined),
                  selectedIcon: const Icon(Icons.forum),
                  label: strings(StringKey.navEveryday),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.mic_none_outlined),
                  selectedIcon: const Icon(Icons.mic),
                  label: strings(StringKey.navProfessional),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.notifications_none),
                  selectedIcon: const Icon(Icons.notifications),
                  label: strings(StringKey.navAlerts),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.settings_outlined),
                  selectedIcon: const Icon(Icons.settings),
                  label: strings(StringKey.navSettings),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Index of each destination, for tests and for cross-screen navigation.
abstract final class MainTab {
  /// The dashboard.
  static const int home = 0;

  /// Everyday conversation.
  static const int everyday = 1;

  /// Professional sessions.
  static const int professional = 2;

  /// Environmental alerts.
  static const int alerts = 3;

  /// Settings.
  static const int settings = 4;
}
