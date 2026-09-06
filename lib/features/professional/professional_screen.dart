import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:humsukhan/application/professional/session_recorder.dart';
import 'package:humsukhan/application/providers.dart';
import 'package:humsukhan/core/failure/failure.dart';
import 'package:humsukhan/core/l10n/app_strings.dart';
import 'package:humsukhan/core/result/result.dart';
import 'package:humsukhan/core/theme/app_tokens.dart';
import 'package:humsukhan/domain/professional/professional_session.dart';
import 'package:humsukhan/domain/professional/retention_policy.dart';
import 'package:humsukhan/domain/speech/language_tag.dart';
import 'package:humsukhan/domain/speech/speech_failure.dart';
import 'package:humsukhan/domain/speech/speech_install_port.dart';
import 'package:humsukhan/features/professional/live_session_view.dart';
import 'package:humsukhan/features/professional/new_session_sheet.dart';
import 'package:humsukhan/features/professional/session_detail_screen.dart';
import 'package:humsukhan/features/shared/badges.dart';
import 'package:humsukhan/features/shared/state_views.dart';

/// The list of saved sessions, and the live recording when there is one.
class ProfessionalScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const ProfessionalScreen({super.key});

  @override
  ConsumerState<ProfessionalScreen> createState() => _ProfessionalScreenState();
}

class _ProfessionalScreenState extends ConsumerState<ProfessionalScreen> {
  /// The saved sessions, as a loading/empty/error surface.
  Future<Result<List<ProfessionalSession>, Failure>>? _sessions;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _sessions = ref
          .read(sessionRepositoryProvider)
          .list()
          .then((Result<List<ProfessionalSession>, Failure> result) => result);
    });
  }

  Future<void> _startSession() async {
    final NewSessionRequest? request =
        await showModalBottomSheet<NewSessionRequest>(
          context: context,
          isScrollControlled: true,
          builder: (BuildContext context) => NewSessionSheet(
            strings: ref.read(stringsProvider),
            defaultLanguage: ref.read(settingsProvider).captionLanguage,
            defaultRetentionDays: ref.read(settingsProvider).retentionDays,
          ),
        );
    if (request == null || !mounted) return;

    // Checked before the session exists, not after: discovering a missing
    // language ten minutes into a lecture is the failure that costs the most,
    // and there is no recovering the words already spoken.
    await ref
        .read(speechSetupProvider.notifier)
        .controller
        .ensure(
          facility: SpeechFacility.recognition,
          language: request.language,
          action: () => _beginRecording(request),
        );
  }

  Future<void> _beginRecording(NewSessionRequest request) async {
    final SessionRecorder recorder = ref
        .read(recorderProvider.notifier)
        .recorder;
    final Result<ProfessionalSession, Failure> result = await recorder.start(
      title: request.title,
      type: request.type,
      language: request.language,
      retentionDays: request.retentionDays,
    );
    if (!mounted) return;
    if (result case Err<ProfessionalSession, Failure>(:final Failure error)) {
      _message(ref.read(stringsProvider).describe(error), isError: true);
    }
  }

  /// Resumes a paused session, reporting a failure rather than sitting still.
  Future<void> _resumeRecording() async {
    final Result<Unit, SttFailure> result = await ref
        .read(recorderProvider.notifier)
        .recorder
        .resume();
    if (!mounted) return;
    if (result case Err<Unit, SttFailure>(:final SttFailure error)) {
      _message(ref.read(stringsProvider).describe(error), isError: true);
    }
  }

  Future<void> _saveRecording() async {
    final SessionRecorder recorder = ref
        .read(recorderProvider.notifier)
        .recorder;
    final ProfessionalSession? session = recorder.state.session;
    final AppStrings strings = ref.read(stringsProvider);
    if (session == null) return;

    final Result<Unit, Failure> result = await ref
        .read(sessionRepositoryProvider)
        .save(session);
    if (!mounted) return;
    result.fold((Unit _) {
      recorder.discard();
      _message(strings(StringKey.proSessionSaved));
      _reload();
    }, (Failure failure) => _message(strings.describe(failure), isError: true));
  }

  Future<void> _delete(ProfessionalSession session) async {
    final Result<Unit, Failure> result = await ref
        .read(sessionRepositoryProvider)
        .delete(session.id);
    if (!mounted) return;
    result.fold(
      (Unit _) => _reload(),
      (Failure failure) =>
          _message(ref.read(stringsProvider).describe(failure), isError: true),
    );
  }

  void _message(String text, {bool isError = false}) {
    if (!mounted) return;
    final ThemeData theme = Theme.of(context);
    // Removed, not cleared: a cleared snack bar animates out, and two snack
    // bars carrying the same text overlap long enough to collide on their
    // shared Hero tag.
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: isError ? theme.colorScheme.error : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = ref.watch(stringsProvider);
    final RecorderState recorder = ref.watch(recorderProvider);

    if (recorder.phase != RecorderPhase.idle) {
      return LiveSessionView(
        state: recorder,
        strings: strings,
        onStop: () =>
            unawaited(ref.read(recorderProvider.notifier).recorder.stop()),
        onPause: () =>
            unawaited(ref.read(recorderProvider.notifier).recorder.pause()),
        onResume: () => unawaited(_resumeRecording()),
        durationOf: (DateTime now) =>
            ref.read(recorderProvider.notifier).recorder.durationAt(now),
        onSave: () => unawaited(_saveRecording()),
        onDiscard: () {
          ref.read(recorderProvider.notifier).recorder.discard();
          _message(strings(StringKey.proSessionDiscarded));
        },
        onAddNote: (String note) =>
            ref.read(recorderProvider.notifier).recorder.addManualCaption(note),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(strings(StringKey.proTitle))),
      floatingActionButton: FloatingActionButton.extended(
        // No hero: this screen stays mounted in the shell's IndexedStack while
        // a detail route is pushed, and two live heroes with the same tag
        // assert during the transition.
        heroTag: null,
        onPressed: () => unawaited(_startSession()),
        icon: const Icon(Icons.fiber_manual_record),
        label: Text(strings(StringKey.proNewSession)),
      ),
      body: FutureBuilder<Result<List<ProfessionalSession>, Failure>>(
        future: _sessions,
        builder:
            (
              BuildContext context,
              AsyncSnapshot<Result<List<ProfessionalSession>, Failure>>
              snapshot,
            ) {
              if (snapshot.connectionState != ConnectionState.done) {
                return LoadingStateView(message: strings(StringKey.loading));
              }
              final Result<List<ProfessionalSession>, Failure>? result =
                  snapshot.data;
              if (result == null) {
                return ErrorStateView(
                  title: strings(StringKey.stateErrorTitle),
                  message: strings(StringKey.somethingWentWrong),
                  onRetry: _reload,
                  retryLabel: strings(StringKey.retry),
                );
              }
              return result.fold(
                (List<ProfessionalSession> sessions) => sessions.isEmpty
                    ? EmptyStateView(
                        title: strings(StringKey.stateEmptyTitle),
                        message: strings(StringKey.proNoSessions),
                        icon: Icons.mic_none_outlined,
                      )
                    : _SessionList(
                        sessions: sessions,
                        strings: strings,
                        onOpen: (ProfessionalSession session) => unawaited(
                          Navigator.of(context)
                              .push(
                                MaterialPageRoute<void>(
                                  builder: (BuildContext context) =>
                                      SessionDetailScreen(
                                        sessionId: session.id,
                                      ),
                                ),
                              )
                              .then((void _) => _reload()),
                        ),
                        onDelete: (ProfessionalSession session) =>
                            unawaited(_delete(session)),
                      ),
                (Failure failure) => ErrorStateView(
                  title: strings(StringKey.stateErrorTitle),
                  message: strings.failureMessage(failure.code),
                  remedy: strings.failureRemedy(failure.code),
                  onRetry: _reload,
                  retryLabel: strings(StringKey.retry),
                ),
              );
            },
      ),
    );
  }
}

class _SessionList extends StatelessWidget {
  const _SessionList({
    required this.sessions,
    required this.strings,
    required this.onOpen,
    required this.onDelete,
  });

  final List<ProfessionalSession> sessions;
  final AppStrings strings;
  final ValueChanged<ProfessionalSession> onOpen;
  final ValueChanged<ProfessionalSession> onDelete;

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.spaceMd,
        AppTokens.spaceMd,
        AppTokens.spaceMd,
        96,
      ),
      itemCount: sessions.length,
      separatorBuilder: (BuildContext context, int index) =>
          const SizedBox(height: AppTokens.spaceSm),
      itemBuilder: (BuildContext context, int index) {
        final ProfessionalSession session = sessions[index];
        final int daysLeft = RetentionPolicy(session.retentionDays)
            .daysRemaining(session.startedAt, now);
        return Card(
          child: ListTile(
            contentPadding: const EdgeInsets.all(AppTokens.spaceMd),
            title: Text(session.title),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: AppTokens.spaceSm),
              child: Wrap(
                spacing: AppTokens.spaceSm,
                runSpacing: AppTokens.spaceXs,
                children: <Widget>[
                  Pill(
                    label: strings(sessionTypeKey(session.type)),
                    icon: Icons.category_outlined,
                  ),
                  Pill(
                    label: strings.format(
                      StringKey.proWordCount,
                      <String, String>{'count': '${session.wordCount}'},
                    ),
                    icon: Icons.notes_outlined,
                  ),
                  RetentionBadge(daysRemaining: daysLeft, strings: strings),
                ],
              ),
            ),
            trailing: IconButton(
              tooltip: strings(StringKey.delete),
              onPressed: () => onDelete(session),
              icon: const Icon(Icons.delete_outline),
            ),
            onTap: () => onOpen(session),
          ),
        );
      },
    );
  }
}

/// The user-facing name of a [SessionType].
StringKey sessionTypeKey(SessionType type) => switch (type) {
  SessionType.meeting => StringKey.proTypeMeeting,
  SessionType.lecture => StringKey.proTypeLecture,
  SessionType.classroom => StringKey.proTypeClass,
};

/// The user-facing name of a caption language.
StringKey captionLanguageKey(LanguageTag tag) => switch (tag) {
  LanguageTag.english => StringKey.setLanguageEnglish,
  LanguageTag.urdu => StringKey.setLanguageUrdu,
};
