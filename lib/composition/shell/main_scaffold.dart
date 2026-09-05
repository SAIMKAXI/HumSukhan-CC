import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:humsukhan/application/providers.dart';
import 'package:humsukhan/core/l10n/app_strings.dart';
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

  void _select(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = ref.watch(stringsProvider);

    return AlertOverlay(
      child: Scaffold(
        body: SafeArea(
          child: IndexedStack(
            index: _index,
            children: <Widget>[
              HomeScreen(onOpenTab: _select),
              const ConversationScreen(),
              const ProfessionalScreen(),
              const EnvironmentScreen(),
              const SettingsScreen(),
            ],
          ),
        ),
        bottomNavigationBar: NavigationBar(
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
