import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:humsukhan/application/settings/settings_controller.dart';
import 'package:humsukhan/application/providers.dart';
import 'package:humsukhan/core/l10n/app_language.dart';
import 'package:humsukhan/core/l10n/app_strings.dart';
import 'package:humsukhan/core/theme/app_tokens.dart';
import 'package:humsukhan/domain/account/account.dart';
import 'package:humsukhan/domain/conversation/turn_policy.dart';
import 'package:humsukhan/domain/environment/model_state.dart';
import 'package:humsukhan/domain/professional/retention_policy.dart';
import 'package:humsukhan/domain/settings/app_settings.dart';
import 'package:humsukhan/domain/speech/language_tag.dart';
import 'package:humsukhan/features/shared/mixed_script_text.dart';
import 'package:humsukhan/features/shared/state_views.dart';

/// Everything the user can change.
class SettingsScreen extends ConsumerWidget {
  /// Creates the screen.
  const SettingsScreen({super.key});

  SettingsController _controller(WidgetRef ref) =>
      ref.read(settingsControllerProvider.notifier).controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppStrings strings = ref.watch(stringsProvider);
    final AppSettings settings = ref.watch(settingsProvider);
    final Account? account = ref.watch(accountProvider);
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(strings(StringKey.setTitle))),
      body: ListView(
        padding: const EdgeInsets.all(AppTokens.spaceMd),
        children: <Widget>[
          if (account != null) ...<Widget>[
            SectionHeader(strings(StringKey.setProfile)),
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    account.greetingName.characters.first.toUpperCase(),
                    style: TextStyle(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                title: Text(account.greetingName),
                subtitle: Text(account.email),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => unawaited(_editName(context, ref, account)),
              ),
            ),
          ],

          SectionHeader(strings(StringKey.setAppearance)),
          SwitchListTile(
            value: settings.darkMode,
            onChanged: settings.highContrast
                ? null
                : (bool value) =>
                      unawaited(_controller(ref).setDarkMode(value)),
            title: Text(strings(StringKey.setDarkMode)),
          ),
          SwitchListTile(
            value: settings.highContrast,
            onChanged: (bool value) =>
                unawaited(_controller(ref).setHighContrast(value)),
            title: Text(strings(StringKey.setHighContrast)),
            subtitle: Text(strings(StringKey.setHighContrastBody)),
          ),
          SwitchListTile(
            value: settings.largeText,
            onChanged: (bool value) =>
                unawaited(_controller(ref).setLargeText(value)),
            title: Text(strings(StringKey.setLargeText)),
            subtitle: Text(strings(StringKey.setLargeTextBody)),
          ),
          ListTile(
            title: Text(strings(StringKey.setCaptionSize)),
            subtitle: Slider(
              value: settings.captionScale,
              min: 0.9,
              max: 1.8,
              divisions: 9,
              label: '${(settings.captionScale * 100).round()}%',
              onChanged: (double value) =>
                  unawaited(_controller(ref).setCaptionScale(value)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTokens.spaceMd),
            child: MixedScriptText(
              strings(StringKey.setCaptionPreview),
              scale: settings.captionScale,
              style: theme.textTheme.bodyLarge,
            ),
          ),

          SectionHeader(strings(StringKey.setLanguage)),
          // Label above, control below, at full width: a segmented control in
          // a ListTile's trailing slot cannot fit a phone, and the Urdu labels
          // are wider still.
          _ChoiceRow(
            label: strings(StringKey.setAppLanguage),
            child: SegmentedButton<AppLanguage>(
              segments: <ButtonSegment<AppLanguage>>[
                ButtonSegment<AppLanguage>(
                  value: AppLanguage.english,
                  label: Text(strings(StringKey.setLanguageEnglish)),
                ),
                ButtonSegment<AppLanguage>(
                  value: AppLanguage.urdu,
                  label: Text(strings(StringKey.setLanguageUrdu)),
                ),
              ],
              selected: <AppLanguage>{settings.appLanguage},
              onSelectionChanged: (Set<AppLanguage> selection) =>
                  unawaited(_controller(ref).setAppLanguage(selection.first)),
            ),
          ),
          _ChoiceRow(
            label: strings(StringKey.setCaptionLanguage),
            child: SegmentedButton<LanguageTag>(
              segments: <ButtonSegment<LanguageTag>>[
                ButtonSegment<LanguageTag>(
                  value: LanguageTag.english,
                  label: Text(strings(StringKey.setLanguageEnglish)),
                ),
                ButtonSegment<LanguageTag>(
                  value: LanguageTag.urdu,
                  label: Text(strings(StringKey.setLanguageUrdu)),
                ),
              ],
              selected: <LanguageTag>{settings.captionLanguage},
              onSelectionChanged: (Set<LanguageTag> selection) => unawaited(
                _controller(ref).setCaptionLanguage(selection.first),
              ),
            ),
          ),

          SectionHeader(strings(StringKey.everydayPauseThreshold)),
          RadioGroup<PauseThreshold>(
            groupValue: settings.pauseThreshold,
            onChanged: (PauseThreshold? value) {
              if (value == null) return;
              unawaited(_controller(ref).setPauseThreshold(value));
            },
            child: Column(
              children: PauseThreshold.values
                  .map(
                    (PauseThreshold threshold) => RadioListTile<PauseThreshold>(
                      value: threshold,
                      title: Text(strings(_thresholdKey(threshold))),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),

          SectionHeader(strings(StringKey.setAlerts)),
          SwitchListTile(
            value: settings.alertChannels.haptic,
            onChanged: (bool value) => unawaited(
              _controller(ref).setAlertChannels(
                settings.alertChannels.copyWith(haptic: value),
              ),
            ),
            title: Text(strings(StringKey.setHaptic)),
          ),
          SwitchListTile(
            value: settings.alertChannels.visual,
            onChanged: (bool value) => unawaited(
              _controller(ref).setAlertChannels(
                settings.alertChannels.copyWith(visual: value),
              ),
            ),
            title: Text(strings(StringKey.setVisual)),
          ),
          SwitchListTile(
            value: settings.alertChannels.screenFlash,
            onChanged: (bool value) => unawaited(
              _controller(ref).setAlertChannels(
                settings.alertChannels.copyWith(screenFlash: value),
              ),
            ),
            title: Text(strings(StringKey.setScreenFlash)),
          ),
          SwitchListTile(
            value: settings.alertChannels.torch,
            onChanged: (bool value) => unawaited(
              _controller(
                ref,
              ).setAlertChannels(settings.alertChannels.copyWith(torch: value)),
            ),
            title: Text(strings(StringKey.setTorch)),
          ),
          if (!settings.alertChannels.hasAny)
            Padding(
              padding: const EdgeInsets.all(AppTokens.spaceMd),
              child: Text(
                // Turning every channel off means no alert can reach the user
                // at all. Say so rather than let it happen quietly.
                strings(StringKey.setNoAlertChannels),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),

          SectionHeader(strings(StringKey.setRetention)),
          ListTile(
            subtitle: Text(strings(StringKey.setRetentionBody)),
            title: Wrap(
              spacing: AppTokens.spaceSm,
              children: RetentionPolicy.choices
                  .map(
                    (int days) => ChoiceChip(
                      label: Text(
                        strings.format(
                          StringKey.proRetentionDays,
                          <String, String>{'days': '$days'},
                        ),
                      ),
                      selected: settings.retentionDays == days,
                      onSelected: (bool _) =>
                          unawaited(_controller(ref).setRetentionDays(days)),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),

          SectionHeader(strings(StringKey.setOfflineModels)),
          _ModelTile(strings: strings),

          SectionHeader(strings(StringKey.setAccount)),
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(strings(StringKey.authSignOut)),
            onTap: () => unawaited(_signOut(context, ref, strings)),
          ),

          const SizedBox(height: AppTokens.spaceXl),
          Center(
            child: Text(
              strings.format(StringKey.setVersion, <String, String>{
                'version': '1.0.0',
              }),
              style: theme.textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: AppTokens.spaceXl),
        ],
      ),
    );
  }

  StringKey _thresholdKey(PauseThreshold threshold) => switch (threshold) {
    PauseThreshold.short => StringKey.pauseShort,
    PauseThreshold.natural => StringKey.pauseNatural,
    PauseThreshold.patient => StringKey.pausePatient,
    PauseThreshold.manual => StringKey.pauseManual,
  };

  Future<void> _editName(
    BuildContext context,
    WidgetRef ref,
    Account account,
  ) async {
    final AppStrings strings = ref.read(stringsProvider);
    final TextEditingController controller = TextEditingController(
      text: account.displayName ?? '',
    );
    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(strings(StringKey.setDisplayName)),
        content: TextField(controller: controller, autofocus: true),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(strings(StringKey.cancel)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(strings(StringKey.save)),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;
    await ref
        .read(authControllerProvider.notifier)
        .controller
        .updateDisplayName(name);
  }

  Future<void> _signOut(
    BuildContext context,
    WidgetRef ref,
    AppStrings strings,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(strings(StringKey.authSignOutConfirm)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(strings(StringKey.cancel)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(strings(StringKey.authSignOut)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(authControllerProvider.notifier).controller.signOut();
  }
}

/// A labelled setting whose control is too wide for a list tile's trailing
/// slot, laid out as a label above a full-width control.
class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: AppTokens.spaceMd,
      vertical: AppTokens.spaceSm,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: AppTokens.spaceSm),
        SizedBox(width: double.infinity, child: child),
      ],
    ),
  );
}

class _ModelTile extends ConsumerWidget {
  const _ModelTile({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ModelState model = ref.watch(monitoringProvider).model;
    final (IconData icon, String label) = switch (model) {
      ModelReady() => (
        Icons.check_circle_outline,
        strings(StringKey.envModelReady),
      ),
      ModelVerifying() => (
        Icons.hourglass_empty,
        strings(StringKey.envModelVerifying),
      ),
      ModelDownloading() => (
        Icons.downloading,
        strings(StringKey.envModelDownloading),
      ),
      ModelAbsent() => (Icons.cloud_off, strings(StringKey.envModelAbsent)),
      ModelFailed(:final ModelFailure cause) => (
        Icons.error_outline,
        strings.describe(cause),
      ),
    };

    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        subtitle: Text(strings(StringKey.envOnDeviceNotice)),
      ),
    );
  }
}
