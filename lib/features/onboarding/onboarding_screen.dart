import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:humsukhan/application/providers.dart';
import 'package:humsukhan/core/l10n/app_strings.dart';
import 'package:humsukhan/core/theme/app_tokens.dart';
import 'package:humsukhan/features/shared/brand_logo.dart';

/// One onboarding page.
class _Page {
  const _Page({
    required this.title,
    required this.body,
    required this.icon,
    this.showLogo = false,
  });

  final StringKey title;
  final StringKey body;
  final IconData icon;
  final bool showLogo;
}

const List<_Page> _pages = <_Page>[
  _Page(
    title: StringKey.onboardWelcomeTitle,
    body: StringKey.onboardWelcomeBody,
    icon: Icons.waving_hand_outlined,
    showLogo: true,
  ),
  _Page(
    title: StringKey.onboardEverydayTitle,
    body: StringKey.onboardEverydayBody,
    icon: Icons.forum_outlined,
  ),
  _Page(
    title: StringKey.onboardProfessionalTitle,
    body: StringKey.onboardProfessionalBody,
    icon: Icons.mic_none_outlined,
  ),
  _Page(
    title: StringKey.onboardEnvironmentTitle,
    body: StringKey.onboardEnvironmentBody,
    icon: Icons.notifications_active_outlined,
  ),
  _Page(
    title: StringKey.onboardPrivacyTitle,
    body: StringKey.onboardPrivacyBody,
    icon: Icons.lock_outline,
  ),
];

/// Five pages explaining the three pillars and the privacy promise.
///
/// Skippable forward and back; completion persists so it is never shown twice.
class OnboardingScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;
  bool _finishing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    // Guard set synchronously so a double tap cannot run this twice.
    if (_finishing) return;
    setState(() => _finishing = true);
    await ref
        .read(settingsControllerProvider.notifier)
        .controller
        .completeOnboarding();
    if (!mounted) return;
    setState(() => _finishing = false);
  }

  void _next() {
    if (_index == _pages.length - 1) {
      unawaited(_finish());
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = ref.watch(stringsProvider);
    final ThemeData theme = Theme.of(context);
    final bool isLast = _index == _pages.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: _finishing ? null : () => unawaited(_finish()),
                child: Text(strings(StringKey.skip)),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (int index) => setState(() => _index = index),
                itemCount: _pages.length,
                itemBuilder: (BuildContext context, int index) {
                  final _Page page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTokens.spaceLg,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        if (page.showLogo)
                          const BrandLogo(size: 112)
                        else
                          Icon(
                            page.icon,
                            size: 72,
                            color: theme.colorScheme.primary,
                          ),
                        const SizedBox(height: AppTokens.spaceXl),
                        Text(
                          strings(page.title),
                          style: theme.textTheme.headlineMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppTokens.spaceMd),
                        Text(
                          strings(page.body),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List<Widget>.generate(
                _pages.length,
                (int index) => Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(
                    horizontal: AppTokens.spaceXs,
                  ),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index == _index
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppTokens.spaceLg),
              child: Row(
                children: <Widget>[
                  if (_index > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _controller.previousPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                        ),
                        child: Text(strings(StringKey.back)),
                      ),
                    ),
                  if (_index > 0) const SizedBox(width: AppTokens.spaceMd),
                  Expanded(
                    child: FilledButton(
                      onPressed: _finishing ? null : _next,
                      child: Text(
                        strings(isLast ? StringKey.getStarted : StringKey.next),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
