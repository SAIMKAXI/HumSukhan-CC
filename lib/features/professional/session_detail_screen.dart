import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:humsukhan/application/common/operation_state.dart';
import 'package:humsukhan/application/providers.dart';
import 'package:humsukhan/core/failure/failure.dart';
import 'package:humsukhan/core/l10n/app_strings.dart';
import 'package:humsukhan/core/result/result.dart';
import 'package:humsukhan/core/theme/app_tokens.dart';
import 'package:humsukhan/domain/conversation/caption.dart';
import 'package:humsukhan/domain/professional/insight.dart';
import 'package:humsukhan/domain/professional/professional_session.dart';
import 'package:humsukhan/domain/professional/retention_policy.dart';
import 'package:humsukhan/features/shared/badges.dart';
import 'package:humsukhan/features/shared/mixed_script_text.dart';
import 'package:humsukhan/features/shared/state_views.dart';
import 'package:share_plus/share_plus.dart';

/// One saved session: overview, summary, actions and the full transcript.
class SessionDetailScreen extends ConsumerStatefulWidget {
  /// Creates the screen for [sessionId].
  const SessionDetailScreen({required this.sessionId, super.key});

  /// Which session to show.
  final String sessionId;

  @override
  ConsumerState<SessionDetailScreen> createState() =>
      _SessionDetailScreenState();
}

class _SessionDetailScreenState extends ConsumerState<SessionDetailScreen> {
  ProfessionalSession? _session;
  Failure? _loadFailure;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailure = null;
    });
    final Result<ProfessionalSession?, Failure> result = await ref
        .read(sessionRepositoryProvider)
        .find(widget.sessionId);
    if (!mounted) return;
    result.fold(
      (ProfessionalSession? session) {
        setState(() {
          _session = session;
          _loading = false;
        });
        ref
            .read(insightServiceProvider.notifier)
            .service
            .seed(session?.insight);
      },
      (Failure failure) => setState(() {
        _loadFailure = failure;
        _loading = false;
      }),
    );
  }

  Future<void> _generate() async {
    final ProfessionalSession? session = _session;
    if (session == null) return;
    final Result<Insight, Failure> result = await ref
        .read(insightServiceProvider.notifier)
        .service
        .generate(
          transcript: session.transcriptText,
          language: session.language,
        );

    if (!mounted) return;
    if (result case Ok<Insight, Failure>(:final Insight value)) {
      final ProfessionalSession updated = session.copyWith(insight: value);
      await ref.read(sessionRepositoryProvider).save(updated);
      if (!mounted) return;
      setState(() => _session = updated);
    }
  }

  Future<void> _share() async {
    final ProfessionalSession? session = _session;
    if (session == null) return;
    final AppStrings strings = ref.read(stringsProvider);
    final StringBuffer buffer = StringBuffer()
      ..writeln(session.title)
      ..writeln();
    final Insight? insight = session.insight;
    if (insight != null) {
      buffer
        ..writeln(strings(StringKey.proSummary))
        ..writeln(insight.summary)
        ..writeln();
      if (insight.actionItems.isNotEmpty) {
        buffer.writeln(strings(StringKey.proActionItems));
        for (final ActionItem item in insight.actionItems) {
          buffer.writeln('- ${item.description}');
        }
        buffer.writeln();
      }
      buffer.writeln(strings(StringKey.aiDisclaimer));
      buffer.writeln();
    }
    buffer
      ..writeln(strings(StringKey.proTranscript))
      ..writeln(session.transcriptText);

    await SharePlus.instance.share(
      ShareParams(text: buffer.toString(), subject: session.title),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = ref.watch(stringsProvider);
    final ProfessionalSession? session = _session;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(),
        body: LoadingStateView(message: strings(StringKey.loading)),
      );
    }

    final Failure? failure = _loadFailure;
    if (failure != null) {
      return Scaffold(
        appBar: AppBar(),
        body: ErrorStateView(
          title: strings(StringKey.stateErrorTitle),
          message: strings.failureMessage(failure.code),
          remedy: strings.failureRemedy(failure.code),
          onRetry: () => unawaited(_load()),
          retryLabel: strings(StringKey.retry),
        ),
      );
    }

    if (session == null) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyStateView(
          title: strings(StringKey.stateEmptyTitle),
          message: strings(StringKey.proNoSessions),
        ),
      );
    }

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(session.title),
          actions: <Widget>[
            IconButton(
              tooltip: strings(StringKey.share),
              onPressed: () => unawaited(_share()),
              icon: const Icon(Icons.ios_share),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabs: <Widget>[
              Tab(text: strings(StringKey.proOverview)),
              Tab(text: strings(StringKey.proSummary)),
              Tab(text: strings(StringKey.proActions)),
              Tab(text: strings(StringKey.proTranscript)),
            ],
          ),
        ),
        body: TabBarView(
          children: <Widget>[
            _OverviewTab(session: session, strings: strings),
            _SummaryTab(
              strings: strings,
              onGenerate: () => unawaited(_generate()),
            ),
            _ActionsTab(
              strings: strings,
              onGenerate: () => unawaited(_generate()),
            ),
            _TranscriptTab(session: session, strings: strings),
          ],
        ),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.session, required this.strings});

  final ProfessionalSession session;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final int daysLeft = RetentionPolicy(session.retentionDays)
        .daysRemaining(session.startedAt, DateTime.now());

    return ListView(
      padding: const EdgeInsets.all(AppTokens.spaceMd),
      children: <Widget>[
        Wrap(
          spacing: AppTokens.spaceSm,
          runSpacing: AppTokens.spaceSm,
          children: <Widget>[
            Pill(
              label: strings(_typeKey(session.type)),
              icon: Icons.category_outlined,
            ),
            Pill(
              label: strings(
                session.language.code == 'ur'
                    ? StringKey.setLanguageUrdu
                    : StringKey.setLanguageEnglish,
              ),
              icon: Icons.translate,
            ),
            RetentionBadge(daysRemaining: daysLeft, strings: strings),
          ],
        ),
        const SizedBox(height: AppTokens.spaceLg),
        _Row(label: strings(StringKey.proDuration), value: _duration(session)),
        _Row(
          label: strings(StringKey.proWordCount).replaceAll('{count} ', ''),
          value: '${session.wordCount}',
        ),
      ],
    );
  }

  String _duration(ProfessionalSession session) {
    final Duration duration = session.durationAt(DateTime.now());
    return '${duration.inMinutes} min';
  }

  StringKey _typeKey(SessionType type) => switch (type) {
    SessionType.meeting => StringKey.proTypeMeeting,
    SessionType.lecture => StringKey.proTypeLecture,
    SessionType.classroom => StringKey.proTypeClass,
  };
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppTokens.spaceSm),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        Text(value, style: Theme.of(context).textTheme.titleSmall),
      ],
    ),
  );
}

class _SummaryTab extends ConsumerWidget {
  const _SummaryTab({required this.strings, required this.onGenerate});

  final AppStrings strings;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OperationState<Object?> state = ref.watch(insightServiceProvider);

    // Three distinct states, never one ambiguous blank (B7).
    return switch (state) {
      OperationLoading<Object?>() => LoadingStateView(
        message: strings(StringKey.proSummaryGenerating),
      ),
      OperationFailure<Object?>(:final Failure failure) => ErrorStateView(
        title: strings(StringKey.stateErrorTitle),
        message: strings.failureMessage(failure.code),
        remedy: strings.failureRemedy(failure.code),
        onRetry: failure.isRecoverable ? onGenerate : null,
        retryLabel: strings(StringKey.retry),
      ),
      OperationSuccess<Object?>(:final Object? value) when value is Insight =>
        ListView(
          padding: const EdgeInsets.all(AppTokens.spaceMd),
          children: <Widget>[
            AiDisclaimer(strings: strings),
            const SizedBox(height: AppTokens.spaceMd),
            MixedScriptText(
              value.summary,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (value.keyPoints.isNotEmpty) ...<Widget>[
              SectionHeader(strings(StringKey.proKeyPoints)),
              ...value.keyPoints.map(
                (String point) => Padding(
                  padding: const EdgeInsets.only(bottom: AppTokens.spaceSm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text('• '),
                      Expanded(child: MixedScriptText(point)),
                    ],
                  ),
                ),
              ),
            ],
            if (value.people.isNotEmpty) ...<Widget>[
              SectionHeader(strings(StringKey.proPeople)),
              Wrap(
                spacing: AppTokens.spaceSm,
                runSpacing: AppTokens.spaceSm,
                children: value.people
                    .map(
                      (String person) =>
                          Pill(label: person, icon: Icons.person_outline),
                    )
                    .toList(growable: false),
              ),
            ],
          ],
        ),
      _ => EmptyStateView(
        title: strings(StringKey.stateEmptyTitle),
        message: strings(StringKey.proSummaryEmpty),
        icon: Icons.auto_awesome_outlined,
        action: FilledButton.icon(
          onPressed: onGenerate,
          icon: const Icon(Icons.auto_awesome),
          label: Text(strings(StringKey.proGenerateSummary)),
        ),
      ),
    };
  }
}

class _ActionsTab extends ConsumerWidget {
  const _ActionsTab({required this.strings, required this.onGenerate});

  final AppStrings strings;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OperationState<Object?> state = ref.watch(insightServiceProvider);
    final Object? value = state.valueOrNull;

    if (state is OperationLoading<Object?>) {
      return LoadingStateView(message: strings(StringKey.proSummaryGenerating));
    }
    if (state case OperationFailure<Object?>(:final Failure failure)) {
      return ErrorStateView(
        title: strings(StringKey.stateErrorTitle),
        message: strings.failureMessage(failure.code),
        remedy: strings.failureRemedy(failure.code),
        onRetry: failure.isRecoverable ? onGenerate : null,
        retryLabel: strings(StringKey.retry),
      );
    }
    if (value is! Insight || value.actionItems.isEmpty) {
      return EmptyStateView(
        title: strings(StringKey.stateEmptyTitle),
        message: strings(StringKey.proSummaryEmpty),
        icon: Icons.task_alt,
        action: FilledButton.icon(
          onPressed: onGenerate,
          icon: const Icon(Icons.auto_awesome),
          label: Text(strings(StringKey.proGenerateSummary)),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppTokens.spaceMd),
      children: <Widget>[
        AiDisclaimer(strings: strings),
        const SizedBox(height: AppTokens.spaceMd),
        ...value.actionItems.map(
          (ActionItem item) => Card(
            margin: const EdgeInsets.only(bottom: AppTokens.spaceSm),
            child: ListTile(
              leading: const Icon(Icons.check_box_outline_blank),
              title: MixedScriptText(item.description),
              subtitle: item.owner == null && item.deadline == null
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(top: AppTokens.spaceXs),
                      child: Wrap(
                        spacing: AppTokens.spaceSm,
                        children: <Widget>[
                          if (item.owner != null)
                            Pill(
                              label: item.owner!,
                              icon: Icons.person_outline,
                            ),
                          if (item.deadline != null)
                            Pill(
                              label: item.deadline!,
                              icon: Icons.event_outlined,
                            ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TranscriptTab extends StatelessWidget {
  const _TranscriptTab({required this.session, required this.strings});

  final ProfessionalSession session;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    if (session.captions.isEmpty) {
      return EmptyStateView(
        title: strings(StringKey.stateEmptyTitle),
        message: strings(StringKey.proNoTranscript),
        icon: Icons.subject,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(AppTokens.spaceMd),
      itemCount: session.captions.length,
      itemBuilder: (BuildContext context, int index) {
        final Caption caption = session.captions[index];
        return Padding(
          key: ValueKey<String>(caption.id),
          padding: const EdgeInsets.only(bottom: AppTokens.spaceSm),
          child: MixedScriptText(
            caption.text,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        );
      },
    );
  }
}
