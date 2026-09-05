import 'package:flutter/material.dart';
import 'package:humsukhan/application/conversation/conversation_session_state.dart';
import 'package:humsukhan/core/l10n/app_strings.dart';
import 'package:humsukhan/core/theme/app_tokens.dart';
import 'package:humsukhan/domain/conversation/turn_policy.dart';

/// The microphone, the live status line, and the pause-length menu.
///
/// The status line is the whole point of the screen for a user who cannot hear:
/// every phase — including `reconnecting` and `failed` — is a distinct visible
/// state, never an internal flag.
class SpeakerControls extends StatelessWidget {
  /// Creates the controls.
  const SpeakerControls({
    required this.state,
    required this.strings,
    required this.onToggleMicrophone,
    required this.onThresholdChanged,
    required this.onStop,
    super.key,
  });

  /// What the session is doing.
  final ConversationSessionState state;

  /// Localised copy.
  final AppStrings strings;

  /// Opens or closes the microphone.
  final VoidCallback onToggleMicrophone;

  /// Changes the pause rule.
  final ValueChanged<PauseThreshold> onThresholdChanged;

  /// Ends the conversation.
  final VoidCallback onStop;

  /// The status line for [state].
  ///
  /// After an utterance has been committed and the microphone is still open,
  /// this says so in words — "speak again to continue" — because the whole
  /// point of B2 is that a pause did not end the session.
  static StringKey statusKey(ConversationSessionState state) =>
      switch (state.phase) {
        ListeningPhase.idle => StringKey.everydayStatusIdle,
        ListeningPhase.starting => StringKey.everydayStatusStarting,
        // Mid-utterance: the other person is talking and we are hearing it.
        ListeningPhase.speaking => StringKey.everydayStatusListening,
        // Open, with nothing in flight. Once something has been captured, the
        // silence the user is looking at is a committed pause, not a dead mic.
        ListeningPhase.listening =>
          state.captions.isEmpty
              ? StringKey.everydayStatusListening
              : StringKey.everydayStatusPaused,
        ListeningPhase.reconnecting => StringKey.everydayStatusReconnecting,
        ListeningPhase.failed => StringKey.everydayStatusFailed,
      };

  /// The label of a pause threshold.
  static StringKey thresholdKey(PauseThreshold threshold) =>
      switch (threshold) {
        PauseThreshold.short => StringKey.pauseShort,
        PauseThreshold.natural => StringKey.pauseNatural,
        PauseThreshold.patient => StringKey.pausePatient,
        PauseThreshold.manual => StringKey.pauseManual,
      };

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool live = state.isMicrophoneOpen;
    final bool busy = state.phase == ListeningPhase.starting;
    final bool failed = state.phase == ListeningPhase.failed;

    return Padding(
      padding: const EdgeInsets.all(AppTokens.spaceMd),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Semantics(
                button: true,
                label: strings(
                  live ? StringKey.everydayMicStop : StringKey.everydayMicStart,
                ),
                child: SizedBox(
                  width: AppTokens.primaryMicSize,
                  height: AppTokens.primaryMicSize,
                  child: Material(
                    color: live ? AppTokens.error : theme.colorScheme.primary,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: busy ? null : onToggleMicrophone,
                      child: Center(
                        child: busy
                            ? const SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                live ? Icons.stop : Icons.mic,
                                size: 34,
                                color: theme.colorScheme.onPrimary,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppTokens.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        strings(statusKey(state)),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: failed
                              ? theme.colorScheme.error
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (state.phase == ListeningPhase.reconnecting)
                      Padding(
                        padding: const EdgeInsets.only(top: AppTokens.spaceXs),
                        child: LinearProgressIndicator(
                          minHeight: 3,
                          color: theme.colorScheme.error,
                        ),
                      ),
                    if (failed && state.failure != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppTokens.spaceXs),
                        child: Text(
                          strings.describe(state.failure!),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<PauseThreshold>(
                tooltip: strings(StringKey.everydayPauseThreshold),
                initialValue: state.threshold,
                onSelected: onThresholdChanged,
                icon: const Icon(Icons.timer_outlined),
                itemBuilder: (BuildContext context) => PauseThreshold.values
                    .map(
                      (PauseThreshold threshold) =>
                          PopupMenuItem<PauseThreshold>(
                            value: threshold,
                            child: Text(strings(thresholdKey(threshold))),
                          ),
                    )
                    .toList(growable: false),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.spaceSm),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: onStop,
              icon: const Icon(Icons.stop_circle_outlined),
              label: Text(strings(StringKey.everydayStop)),
            ),
          ),
        ],
      ),
    );
  }
}
