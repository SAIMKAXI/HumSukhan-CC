import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:humsukhan/application/providers.dart';
import 'package:humsukhan/application/speech/speech_setup_controller.dart';
import 'package:humsukhan/core/l10n/app_strings.dart';
import 'package:humsukhan/core/theme/app_tokens.dart';
import 'package:humsukhan/domain/speech/speech_install_port.dart';

/// The whole "this language needs a download" conversation, in one sheet.
///
/// Deliberately small: a title, a sentence, and at most two buttons. The user
/// is in the middle of trying to talk to someone, and the correct amount of
/// explanation is the least that lets them press the right thing.
///
/// Mounted once, in the app shell, so every feature gets the flow without
/// having to remember to show it.
class SpeechSetupSheet extends ConsumerStatefulWidget {
  /// Creates the sheet host.
  const SpeechSetupSheet({required this.child, super.key});

  /// The app beneath the sheet.
  final Widget child;

  @override
  ConsumerState<SpeechSetupSheet> createState() => _SpeechSetupSheetState();
}

class _SpeechSetupSheetState extends ConsumerState<SpeechSetupSheet>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from the system installer is the only signal Android gives
    // us that a voice may now exist. Without this the flow would sit on
    // "waiting" for ever and the user would have to start again.
    if (state == AppLifecycleState.resumed) {
      ref.read(speechSetupProvider.notifier).controller.onResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final SpeechSetupState setup = ref.watch(speechSetupProvider);
    return Stack(
      children: <Widget>[
        widget.child,
        if (setup.isActive)
          _SetupScrim(
            state: setup,
            strings: ref.watch(stringsProvider),
            onAccept: () =>
                ref.read(speechSetupProvider.notifier).controller.accept(),
            onDismiss: () =>
                ref.read(speechSetupProvider.notifier).controller.dismiss(),
          ),
      ],
    );
  }
}

class _SetupScrim extends StatelessWidget {
  const _SetupScrim({
    required this.state,
    required this.strings,
    required this.onAccept,
    required this.onDismiss,
  });

  final SpeechSetupState state;
  final AppStrings strings;
  final VoidCallback onAccept;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool recognition = state.facility == SpeechFacility.recognition;

    return Positioned.fill(
      child: Semantics(
        // A modal barrier the screen reader announces, rather than a visual
        // dimming that assistive technology walks straight past.
        scopesRoute: true,
        explicitChildNodes: true,
        child: ColoredBox(
          color: Colors.black54,
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppTokens.spaceLg),
                child: Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(AppTokens.spaceLg),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          strings(
                            recognition
                                ? StringKey.setupSttTitle
                                : StringKey.setupTtsTitle,
                          ),
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: AppTokens.spaceMd),
                        _Body(
                          state: state,
                          strings: strings,
                          recognition: recognition,
                        ),
                        const SizedBox(height: AppTokens.spaceLg),
                        _Actions(
                          state: state,
                          strings: strings,
                          onAccept: onAccept,
                          onDismiss: onDismiss,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.state,
    required this.strings,
    required this.recognition,
  });

  final SpeechSetupState state;
  final AppStrings strings;
  final bool recognition;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final InstallProgress? progress = state.progress;

    final (String message, double? bar, bool showBar) = switch (progress) {
      InstallStarting() => (
        strings(recognition ? StringKey.setupSttBody : StringKey.setupTtsBody),
        null,
        false,
      ),
      // A null progress renders an indeterminate bar. Inventing a percentage
      // the platform never gave us would be a more comfortable lie.
      InstallDownloading(:final double? progress) => (
        strings(StringKey.setupDownloading),
        progress,
        true,
      ),
      InstallHandedOff() => (strings(StringKey.setupHandedOff), null, false),
      InstallVerifying() => (strings(StringKey.setupVerifying), null, true),
      InstallCompleted() => (strings(StringKey.setupReady), 1, true),
      InstallFailed(:final reason, :final canRetry) => (
        canRetry
            ? '${strings(StringKey.setupFailed)} ${strings.failureMessage(reason)}'
            : strings(StringKey.setupUnsupported),
        null,
        false,
      ),
      null => (strings(StringKey.setupPreparing), null, true),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(message, style: theme.textTheme.bodyLarge),
        if (showBar) ...<Widget>[
          const SizedBox(height: AppTokens.spaceMd),
          // Progress is announced as text as well as drawn: this app's users
          // may not hear a completion sound, and a bar alone communicates
          // nothing to a screen reader.
          Semantics(
            liveRegion: true,
            value: bar == null
                ? strings(StringKey.setupDownloading)
                : '${(bar * 100).round()}%',
            child: LinearProgressIndicator(value: bar),
          ),
        ],
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.state,
    required this.strings,
    required this.onAccept,
    required this.onDismiss,
  });

  final SpeechSetupState state;
  final AppStrings strings;
  final VoidCallback onAccept;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final InstallProgress? progress = state.progress;

    // Which buttons exist is derived from the state, never from a separate
    // flag: that is what stops a "Download" button surviving into a screen
    // where pressing it would do nothing.
    final bool offerDownload =
        progress is InstallStarting ||
        (progress is InstallFailed && progress.canRetry);
    final bool working =
        progress is InstallDownloading ||
        progress is InstallVerifying ||
        progress is InstallCompleted;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        TextButton(
          onPressed: onDismiss,
          child: Text(
            strings(working ? StringKey.cancel : StringKey.setupNotNow),
          ),
        ),
        if (offerDownload) ...<Widget>[
          const SizedBox(width: AppTokens.spaceSm),
          FilledButton(
            onPressed: onAccept,
            child: Text(
              strings(
                progress is InstallFailed
                    ? StringKey.retry
                    : StringKey.setupDownload,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
