import 'dart:async';

import 'package:flutter/material.dart';
import 'package:humsukhan/application/professional/session_recorder.dart';
import 'package:humsukhan/core/l10n/app_strings.dart';
import 'package:humsukhan/core/theme/app_tokens.dart';
import 'package:humsukhan/domain/conversation/caption.dart';
import 'package:humsukhan/domain/professional/professional_session.dart';
import 'package:humsukhan/features/shared/mixed_script_text.dart';
import 'package:humsukhan/features/shared/state_views.dart';

/// The live recording: a growing transcript of *finalised* captions only.
class LiveSessionView extends StatefulWidget {
  /// Creates the view.
  const LiveSessionView({
    required this.state,
    required this.strings,
    required this.onStop,
    required this.onPause,
    required this.onResume,
    required this.durationOf,
    required this.onSave,
    required this.onDiscard,
    required this.onAddNote,
    super.key,
  });

  /// What the recorder is doing.
  final RecorderState state;

  /// Localised copy.
  final AppStrings strings;

  /// Stops recording.
  final VoidCallback onStop;

  /// Pauses capture, keeping the session open.
  final VoidCallback onPause;

  /// Resumes a paused session into the same transcript.
  final VoidCallback onResume;

  /// How long the session has been recording, excluding time spent paused.
  ///
  /// Supplied rather than derived from `startedAt` here, because wall-clock
  /// elapsed would keep climbing through a break the user deliberately took.
  final Duration Function(DateTime now) durationOf;

  /// Saves the finished session.
  final VoidCallback onSave;

  /// Throws the finished session away.
  final VoidCallback onDiscard;

  /// Adds a typed line to the transcript.
  final ValueChanged<String> onAddNote;

  @override
  State<LiveSessionView> createState() => _LiveSessionViewState();
}

class _LiveSessionViewState extends State<LiveSessionView> {
  final TextEditingController _note = TextEditingController();
  final ScrollController _scroll = ScrollController();
  Timer? _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (Timer _) {
      // Liveness check before touching state.
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _note.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final int minutes = duration.inMinutes;
    final int seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppStrings strings = widget.strings;
    final ProfessionalSession? session = widget.state.session;
    final bool active = widget.state.isActive;
    final bool stopped = widget.state.phase == RecorderPhase.stopped;

    return Scaffold(
      appBar: AppBar(
        title: Text(session?.title ?? strings(StringKey.proTitle)),
        actions: <Widget>[
          if (session != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: AppTokens.spaceMd),
                child: Text(
                  _formatDuration(widget.durationOf(_now)),
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: <Widget>[
          _StatusBanner(state: widget.state, strings: strings),
          Expanded(
            child: session == null || session.captions.isEmpty
                ? EmptyStateView(
                    title: strings(StringKey.proInterimHidden),
                    message: strings(StringKey.proNoTranscript),
                    icon: Icons.subject,
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(AppTokens.spaceMd),
                    itemCount: session.captions.length,
                    itemBuilder: (BuildContext context, int index) {
                      final Caption caption = session.captions[index];
                      return Padding(
                        key: ValueKey<String>(caption.id),
                        padding: const EdgeInsets.only(
                          bottom: AppTokens.spaceSm,
                        ),
                        child: MixedScriptText(
                          caption.text,
                          style: caption.speaker == CaptionSpeaker.own
                              ? theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontStyle: FontStyle.italic,
                                )
                              : theme.textTheme.bodyLarge,
                        ),
                      );
                    },
                  ),
          ),
          // Available while paused too: jotting a line during a break is
          // exactly when somebody would want to.
          if (active)
            Padding(
              padding: const EdgeInsets.all(AppTokens.spaceMd),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _note,
                      decoration: InputDecoration(
                        hintText: strings(StringKey.proAddNote),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTokens.spaceSm),
                  IconButton.filled(
                    onPressed: () {
                      final String text = _note.text.trim();
                      if (text.isEmpty) return;
                      widget.onAddNote(text);
                      _note.clear();
                    },
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(AppTokens.spaceMd),
            child: Row(
              children: <Widget>[
                if (active) ...<Widget>[
                  // Offered only in the phases that can honour it, so the
                  // button is never present and inert.
                  if (widget.state.canPause || widget.state.canResume)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: widget.state.canResume
                            ? widget.onResume
                            : widget.onPause,
                        icon: Icon(
                          widget.state.canResume
                              ? Icons.play_arrow
                              : Icons.pause,
                        ),
                        label: Text(
                          strings(
                            widget.state.canResume
                                ? StringKey.proResume
                                : StringKey.proPause,
                          ),
                        ),
                      ),
                    ),
                  if (widget.state.canPause || widget.state.canResume)
                    const SizedBox(width: AppTokens.spaceMd),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: widget.onStop,
                      icon: const Icon(Icons.stop),
                      label: Text(strings(StringKey.proStopRecording)),
                    ),
                  ),
                ],
                if (!active) ...<Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: widget.onDiscard,
                      icon: const Icon(Icons.delete_outline),
                      label: Text(strings(StringKey.discard)),
                    ),
                  ),
                  const SizedBox(width: AppTokens.spaceMd),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed:
                          stopped || widget.state.phase == RecorderPhase.failed
                          ? widget.onSave
                          : null,
                      icon: const Icon(Icons.save_outlined),
                      label: Text(strings(StringKey.save)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.state, required this.strings});

  final RecorderState state;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final (Color fill, Color ink, String label) = switch (state.phase) {
      RecorderPhase.starting => (
        theme.colorScheme.secondaryContainer,
        theme.colorScheme.onSecondaryContainer,
        strings(StringKey.everydayStatusStarting),
      ),
      RecorderPhase.recording => (
        AppTokens.error,
        Colors.white,
        strings(StringKey.proRecording),
      ),
      RecorderPhase.reconnecting => (
        AppTokens.warning,
        Colors.black,
        strings(StringKey.everydayStatusReconnecting),
      ),
      // Not red. Paused is a state the user chose, and colouring it like a
      // failure would read as one — the more so for a reader who cannot hear
      // that nothing is wrong.
      RecorderPhase.paused => (
        theme.colorScheme.secondaryContainer,
        theme.colorScheme.onSecondaryContainer,
        strings(StringKey.proPaused),
      ),
      RecorderPhase.resuming => (
        theme.colorScheme.secondaryContainer,
        theme.colorScheme.onSecondaryContainer,
        strings(StringKey.proResuming),
      ),
      RecorderPhase.failed => (
        theme.colorScheme.errorContainer,
        theme.colorScheme.onErrorContainer,
        state.failure == null
            ? strings(StringKey.everydayStatusFailed)
            : strings.describe(state.failure!),
      ),
      RecorderPhase.stopped || RecorderPhase.idle => (
        theme.colorScheme.surfaceContainerHighest,
        theme.colorScheme.onSurface,
        strings(StringKey.proSaveTitle),
      ),
    };

    return Container(
      width: double.infinity,
      color: fill,
      padding: const EdgeInsets.all(AppTokens.spaceSm + 4),
      child: Semantics(
        liveRegion: true,
        child: Row(
          children: <Widget>[
            Icon(
              state.phase == RecorderPhase.recording
                  ? Icons.fiber_manual_record
                  : Icons.info_outline,
              size: 18,
              color: ink,
            ),
            const SizedBox(width: AppTokens.spaceSm),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(color: ink),
              ),
            ),
            if (state.hasSpeechInFlight)
              // Says that speech is being heard without showing the unstable
              // text: interim results never reach a Professional transcript.
              Icon(Icons.graphic_eq, size: 18, color: ink),
          ],
        ),
      ),
    );
  }
}
