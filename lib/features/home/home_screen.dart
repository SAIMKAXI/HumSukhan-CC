import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:humsukhan/application/providers.dart';
import 'package:humsukhan/core/failure/failure.dart';
import 'package:humsukhan/core/l10n/app_strings.dart';
import 'package:humsukhan/core/result/result.dart';
import 'package:humsukhan/core/theme/app_tokens.dart';
import 'package:humsukhan/domain/account/account.dart';
import 'package:humsukhan/domain/conversation/conversation.dart';
import 'package:humsukhan/domain/professional/professional_session.dart';
import 'package:humsukhan/features/shared/badges.dart';
import 'package:humsukhan/features/shared/brand_logo.dart';
import 'package:humsukhan/features/shared/state_views.dart';

/// The dashboard: who you are, whether you are online, and the three pillars.
class HomeScreen extends ConsumerStatefulWidget {
  /// Creates the screen. [onOpenTab] switches the main scaffold's tab.
  const HomeScreen({required this.onOpenTab, super.key});

  /// Opens one of the five destinations by index.
  final ValueChanged<int> onOpenTab;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _online = true;
  StreamSubscription<List<ConnectivityResult>>? _connectivity;
  Future<_Recent>? _recent;

  @override
  void initState() {
    super.initState();
    _watchConnectivity();
    _loadRecent();
  }

  @override
  void dispose() {
    unawaited(_connectivity?.cancel());
    super.dispose();
  }

  void _watchConnectivity() {
    final Connectivity connectivity = Connectivity();
    unawaited(
      connectivity.checkConnectivity().then(_apply).catchError((Object error) {
        // Connectivity is a hint, not a gate; failing to read it must not blank
        // the screen, but it is not silently ignored either.
        if (mounted) setState(() => _online = true);
      }),
    );
    _connectivity = connectivity.onConnectivityChanged.listen(
      _apply,
      onError: (Object error, StackTrace stackTrace) {
        if (mounted) setState(() => _online = true);
      },
    );
  }

  void _apply(List<ConnectivityResult> results) {
    if (!mounted) return;
    setState(
      () => _online = results.any(
        (ConnectivityResult r) => r != ConnectivityResult.none,
      ),
    );
  }

  void _loadRecent() {
    setState(() {
      _recent =
          Future.wait<Object>(<Future<Object>>[
            ref.read(conversationRepositoryProvider).list(),
            ref.read(sessionRepositoryProvider).list(),
          ]).then((List<Object> results) {
            final Result<List<Conversation>, Failure> conversations =
                results[0] as Result<List<Conversation>, Failure>;
            final Result<List<ProfessionalSession>, Failure> sessions =
                results[1] as Result<List<ProfessionalSession>, Failure>;
            return _Recent(
              conversations:
                  conversations.valueOrNull ?? const <Conversation>[],
              sessions: sessions.valueOrNull ?? const <ProfessionalSession>[],
              failure: conversations.errorOrNull ?? sessions.errorOrNull,
            );
          });
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = ref.watch(stringsProvider);
    final Account? account = ref.watch(accountProvider);
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => _loadRecent(),
        child: ListView(
          padding: const EdgeInsets.all(AppTokens.spaceMd),
          children: <Widget>[
            Row(
              children: <Widget>[
                const BrandLogo(size: 48),
                const SizedBox(width: AppTokens.spaceMd),
                Expanded(
                  child: Text(
                    account == null
                        ? strings(StringKey.homeGreetingAnonymous)
                        : strings.format(
                            StringKey.homeGreeting,
                            <String, String>{'name': account.greetingName},
                          ),
                    style: theme.textTheme.headlineMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.spaceMd),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: ConnectivityBadge(online: _online, strings: strings),
            ),
            const SizedBox(height: AppTokens.spaceLg),
            _ModeCard(
              title: strings(StringKey.homeEverydayCard),
              body: strings(StringKey.homeEverydayCardBody),
              icon: Icons.forum_outlined,
              onTap: () => widget.onOpenTab(1),
            ),
            const SizedBox(height: AppTokens.spaceSm),
            _ModeCard(
              title: strings(StringKey.homeProfessionalCard),
              body: strings(StringKey.homeProfessionalCardBody),
              icon: Icons.mic_none_outlined,
              onTap: () => widget.onOpenTab(2),
            ),
            const SizedBox(height: AppTokens.spaceSm),
            _ModeCard(
              title: strings(StringKey.homeAlertsCard),
              body: strings(StringKey.homeAlertsCardBody),
              icon: Icons.notifications_none,
              onTap: () => widget.onOpenTab(3),
            ),
            SectionHeader(strings(StringKey.homeRecentActivity)),
            FutureBuilder<_Recent>(
              future: _recent,
              builder: (BuildContext context, AsyncSnapshot<_Recent> snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return Padding(
                    padding: const EdgeInsets.all(AppTokens.spaceLg),
                    child: LoadingStateView(
                      message: strings(StringKey.loading),
                    ),
                  );
                }
                final _Recent? recent = snapshot.data;
                if (recent == null) {
                  return ErrorStateView(
                    title: strings(StringKey.stateErrorTitle),
                    message: strings(StringKey.somethingWentWrong),
                    onRetry: _loadRecent,
                    retryLabel: strings(StringKey.retry),
                  );
                }
                final Failure? failure = recent.failure;
                if (failure != null) {
                  return ErrorStateView(
                    title: strings(StringKey.stateErrorTitle),
                    message: strings.failureMessage(failure.code),
                    remedy: strings.failureRemedy(failure.code),
                    onRetry: _loadRecent,
                    retryLabel: strings(StringKey.retry),
                  );
                }
                if (recent.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(AppTokens.spaceLg),
                    child: EmptyStateView(
                      title: strings(StringKey.stateEmptyTitle),
                      message: strings(StringKey.homeNoActivity),
                      icon: Icons.history,
                    ),
                  );
                }
                return Column(
                  children: <Widget>[
                    ...recent.sessions
                        .take(3)
                        .map(
                          (ProfessionalSession session) => ListTile(
                            leading: const Icon(Icons.mic_none_outlined),
                            title: Text(session.title),
                            subtitle: Text(
                              strings.format(
                                StringKey.proWordCount,
                                <String, String>{
                                  'count': '${session.wordCount}',
                                },
                              ),
                            ),
                            onTap: () => widget.onOpenTab(2),
                          ),
                        ),
                    ...recent.conversations
                        .take(3)
                        .map(
                          (Conversation conversation) => ListTile(
                            leading: const Icon(Icons.forum_outlined),
                            title: Text(
                              conversation.title ??
                                  strings(StringKey.navEveryday),
                            ),
                            subtitle: Text('${conversation.captions.length}'),
                            onTap: () => widget.onOpenTab(1),
                          ),
                        ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Recent {
  const _Recent({
    required this.conversations,
    required this.sessions,
    this.failure,
  });

  final List<Conversation> conversations;
  final List<ProfessionalSession> sessions;
  final Failure? failure;

  bool get isEmpty => conversations.isEmpty && sessions.isEmpty;
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.title,
    required this.body,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String body;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.spaceMd),
          child: Row(
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                ),
                child: Icon(icon, color: theme.colorScheme.onPrimaryContainer),
              ),
              const SizedBox(width: AppTokens.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: AppTokens.spaceXs),
                    Text(
                      body,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
