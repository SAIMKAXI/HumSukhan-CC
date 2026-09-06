import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:humsukhan/application/conversation/conversation_session.dart';
import 'package:humsukhan/application/conversation/conversation_session_state.dart';
import 'package:humsukhan/application/providers.dart';
import 'package:humsukhan/core/failure/failure.dart';
import 'package:humsukhan/core/l10n/app_strings.dart';
import 'package:humsukhan/core/result/result.dart';
import 'package:humsukhan/core/theme/app_tokens.dart';
import 'package:humsukhan/domain/conversation/caption.dart';
import 'package:humsukhan/domain/conversation/conversation.dart';
import 'package:humsukhan/domain/conversation/turn_policy.dart';
import 'package:humsukhan/domain/speech/language_policy.dart';
import 'package:humsukhan/domain/speech/speech_failure.dart';
import 'package:humsukhan/features/conversation/conversation_composer.dart';
import 'package:humsukhan/domain/speech/speech_install_port.dart';
import 'package:humsukhan/features/conversation/speaker_controls.dart';
import 'package:humsukhan/features/shared/caption_bubble.dart';
import 'package:humsukhan/features/shared/state_views.dart';

/// Everyday mode: live captions of the person speaking, and spoken replies.
class ConversationScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const ConversationScreen({super.key});

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final ScrollController _scroll = ScrollController();

  /// How far from the bottom still counts as "reading the latest".
  ///
  /// Roughly one line of caption text, so a pixel of drift from a rebuild does
  /// not read as the user having deliberately scrolled away.
  static const double _stickyThreshold = 80;

  /// Whether new captions should pull the view down with them.
  ///
  /// True while the user is reading the newest text. It goes false the moment
  /// they scroll back to re-read something, and only they can set it true
  /// again — by scrolling back down, or by pressing *Latest*.
  bool _followLatest = true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScrolled);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScrolled)
      ..dispose();
    super.dispose();
  }

  void _onScrolled() {
    if (!_scroll.hasClients) return;
    final ScrollPosition position = _scroll.position;
    final bool atEnd =
        position.pixels >= position.maxScrollExtent - _stickyThreshold;
    if (atEnd == _followLatest) return;
    setState(() => _followLatest = atEnd);
  }

  ConversationSession get _session =>
      ref.read(conversationProvider.notifier).session;

  /// Scrolls to the newest caption.
  ///
  /// [force] is for scrolling the user asked for — sending a reply, or pressing
  /// *Latest*. Everything else defers to [_followLatest]: dragging a reader
  /// back down mid-sentence, every time somebody speaks, makes a long
  /// conversation impossible to re-read (instructions §6).
  void _scrollToEnd({bool force = false}) {
    if (!force && !_followLatest) return;
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (!mounted || !_scroll.hasClients) return;
      if (force && !_followLatest) setState(() => _followLatest = true);
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _toggleMicrophone() async {
    final ConversationSessionState state = ref.read(conversationProvider);
    if (state.isMicrophoneOpen) {
      await _session.stopListening();
      return;
    }
    // The capability check happens here rather than inside the session,
    // because only the UI layer can put the download in front of the user —
    // and if it works out, `ensure` runs the listen itself, so a successful
    // install lands the user in a live conversation rather than back at a
    // button they have to press again.
    await ref
        .read(speechSetupProvider.notifier)
        .controller
        .ensure(
          facility: SpeechFacility.recognition,
          language: _session.captionLanguage,
          action: _startListening,
        );
  }

  Future<void> _startListening() async {
    final Result<Unit, SttFailure> result = await _session.startListening();
    // The failure is already in the state; this makes it unmissable.
    if (result case Err<Unit, SttFailure>(:final SttFailure error)) {
      _announce(error, isError: true);
    }
  }

  Future<void> _speak(String text, {String? captionId}) async {
    // Speaking Urdu on a phone with no Urdu voice is the single most common
    // way this app used to fail silently. The same guided download answers it.
    await ref
        .read(speechSetupProvider.notifier)
        .controller
        .ensure(
          facility: SpeechFacility.synthesis,
          language: _session.languageOf(text),
          action: () => _speakNow(text, captionId: captionId),
        );
  }

  Future<void> _speakNow(String text, {String? captionId}) async {
    final Result<Unit, TtsFailure> result = await _session.speak(
      text,
      captionId: captionId,
    );
    if (result case Err<Unit, TtsFailure>(:final TtsFailure error)) {
      _announce(error, isError: true);
    }
  }

  Future<void> _send(String text, {required bool alsoSpeak}) async {
    final Caption? caption = _session.sendTyped(text);
    if (caption == null) return;
    _scrollToEnd(force: true);
    if (alsoSpeak) await _speak(caption.text, captionId: caption.id);
  }

  Future<void> _save() async {
    final Conversation conversation = _session.toConversation();
    final AppStrings strings = ref.read(stringsProvider);
    final Result<Unit, Failure> result = await ref
        .read(conversationRepositoryProvider)
        .save(conversation);
    if (!mounted) return;
    result.fold((Unit _) {
      _session.reset();
      _message(strings(StringKey.everydaySaved));
    }, (Failure failure) => _message(strings.describe(failure), isError: true));
  }

  void _discard() {
    _session.reset();
    _message(ref.read(stringsProvider)(StringKey.everydayDeleted));
  }

  void _announce(Failure failure, {bool isError = false}) =>
      _message(ref.read(stringsProvider).describe(failure), isError: isError);

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
          duration: const Duration(seconds: 5),
          backgroundColor: isError ? theme.colorScheme.error : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final ConversationSessionState state = ref.watch(conversationProvider);
    final AppStrings strings = ref.watch(stringsProvider);
    final double captionScale = ref.watch(settingsProvider).captionScale;

    ref.listen<ConversationSessionState>(conversationProvider, (
      ConversationSessionState? previous,
      ConversationSessionState next,
    ) {
      if (next.captions.length != (previous?.captions.length ?? 0)) {
        _scrollToEnd();
      }
      final Failure? failure = next.failure;
      if (failure != null && failure != previous?.failure) {
        _announce(failure, isError: true);
      }
    });

    return Scaffold(
      appBar: AppBar(title: Text(strings(StringKey.everydayTitle))),
      body: switch (state.stage) {
        ConversationStage.idle => _IdleView(
          strings: strings,
          onStart: () => _session.begin(),
        ),
        ConversationStage.active => _ActiveView(
          state: state,
          strings: strings,
          scroll: _scroll,
          captionScale: captionScale,
          followingLatest: _followLatest,
          onJumpToLatest: () => _scrollToEnd(force: true),
          onToggleMicrophone: () => unawaited(_toggleMicrophone()),
          onThresholdChanged: _session.setThreshold,
          onSpeakCaption: (Caption caption) =>
              unawaited(_speak(caption.text, captionId: caption.id)),
          onStopSpeaking: () => unawaited(_session.stopSpeaking()),
          onSend: (String text) => unawaited(_send(text, alsoSpeak: false)),
          onSpeakText: (String text) => unawaited(_send(text, alsoSpeak: true)),
          onStop: () => unawaited(_session.stop()),
        ),
        ConversationStage.saveDecision => _SaveDecisionView(
          strings: strings,
          hasContent: state.hasContent,
          onSave: () => unawaited(_save()),
          onDelete: _discard,
          onContinue: _session.resume,
        ),
      },
    );
  }
}

class _IdleView extends StatelessWidget {
  const _IdleView({required this.strings, required this.onStart});

  final AppStrings strings;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppTokens.spaceLg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(
            Icons.forum_outlined,
            size: 64,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: AppTokens.spaceLg),
          Text(
            strings(StringKey.everydayIdleHint),
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTokens.spaceLg),
          Container(
            padding: const EdgeInsets.all(AppTokens.spaceMd),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(AppTokens.radiusSm),
              border: Border.all(color: theme.colorScheme.outline),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.shield_outlined,
                  size: 18,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: AppTokens.spaceSm),
                Expanded(
                  child: Text(
                    strings(StringKey.everydayPrivacyNotice),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.spaceXl),
          FilledButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.play_arrow),
            label: Text(strings(StringKey.everydayStart)),
          ),
        ],
      ),
    );
  }
}

class _ActiveView extends StatelessWidget {
  const _ActiveView({
    required this.state,
    required this.strings,
    required this.scroll,
    required this.captionScale,
    required this.onToggleMicrophone,
    required this.onThresholdChanged,
    required this.onSpeakCaption,
    required this.onStopSpeaking,
    required this.onSend,
    required this.onSpeakText,
    required this.onStop,
    required this.followingLatest,
    required this.onJumpToLatest,
  });

  final ConversationSessionState state;
  final AppStrings strings;
  final ScrollController scroll;
  final double captionScale;

  /// Whether the view is tracking the newest caption.
  final bool followingLatest;

  /// Returns the reader to the newest caption.
  final VoidCallback onJumpToLatest;
  final VoidCallback onToggleMicrophone;
  final ValueChanged<PauseThreshold> onThresholdChanged;
  final ValueChanged<Caption> onSpeakCaption;
  final VoidCallback onStopSpeaking;
  final ValueChanged<String> onSend;
  final ValueChanged<String> onSpeakText;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final bool hasPartial = state.partialText.trim().isNotEmpty;

    return Column(
      children: <Widget>[
        SpeakerControls(
          state: state,
          strings: strings,
          onToggleMicrophone: onToggleMicrophone,
          onThresholdChanged: onThresholdChanged,
          onStop: onStop,
        ),
        const Divider(height: 1),
        Expanded(
          child: state.captions.isEmpty && !hasPartial
              ? EmptyStateView(
                  title: strings(StringKey.everydayNoCaptions),
                  icon: Icons.hearing_outlined,
                )
              : Stack(
                  children: <Widget>[
                    ListView.builder(
                      controller: scroll,
                      padding: const EdgeInsets.all(AppTokens.spaceMd),
                      itemCount: state.captions.length + (hasPartial ? 1 : 0),
                      itemBuilder: (BuildContext context, int index) {
                        if (index >= state.captions.length) {
                          return PartialCaptionBubble(
                            text: state.partialText,
                            strings: strings,
                            captionScale: captionScale,
                          );
                        }
                        final Caption caption = state.captions[index];
                        return SpeakableCaptionBubble(
                          // Keyed by id so a rebuild never re-associates a bubble
                          // with a different caption.
                          key: ValueKey<String>(caption.id),
                          caption: caption,
                          strings: strings,
                          isSpeaking: state.speakingCaptionId == caption.id,
                          captionScale: captionScale,
                          onSpeak: () => onSpeakCaption(caption),
                          onStopSpeaking: onStopSpeaking,
                        );
                      },
                    ),
                    // Only while the reader has scrolled away. Without it,
                    // someone re-reading an earlier answer has no way back to
                    // the live end of a conversation that is still moving.
                    if (!followingLatest)
                      Positioned(
                        right: AppTokens.spaceMd,
                        bottom: AppTokens.spaceMd,
                        child: FloatingActionButton.extended(
                          heroTag: 'conversation-latest',
                          onPressed: onJumpToLatest,
                          icon: const Icon(Icons.arrow_downward),
                          label: Text(strings(StringKey.everydayJumpToLatest)),
                        ),
                      ),
                  ],
                ),
        ),
        ConversationComposer(
          strings: strings,
          locked: state.inputLocked,
          lockedReason: state.isMicrophoneOpen
              ? strings(StringKey.everydayControlsDisabledWhileListening)
              : null,
          onSend: onSend,
          onSpeak: onSpeakText,
        ),
      ],
    );
  }
}

class _SaveDecisionView extends StatelessWidget {
  const _SaveDecisionView({
    required this.strings,
    required this.hasContent,
    required this.onSave,
    required this.onDelete,
    required this.onContinue,
  });

  final AppStrings strings;
  final bool hasContent;
  final VoidCallback onSave;
  final VoidCallback onDelete;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppTokens.spaceLg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            strings(StringKey.everydaySaveTitle),
            style: theme.textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTokens.spaceMd),
          Text(
            strings(StringKey.everydaySaveBody),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTokens.spaceXl),
          FilledButton.icon(
            // Disabled with nothing to save, rather than silently saving an
            // empty conversation.
            onPressed: hasContent ? onSave : null,
            icon: const Icon(Icons.save_outlined),
            label: Text(strings(StringKey.save)),
          ),
          const SizedBox(height: AppTokens.spaceSm),
          OutlinedButton.icon(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
            label: Text(strings(StringKey.delete)),
          ),
          const SizedBox(height: AppTokens.spaceSm),
          TextButton(
            onPressed: onContinue,
            child: Text(strings(StringKey.continueLabel)),
          ),
        ],
      ),
    );
  }
}

/// The language a caption was classified as, for the screen's own use.
CaptionLanguage classifyForDisplay(String text) =>
    LanguagePolicy.classify(text);
