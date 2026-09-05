import 'package:flutter/material.dart';
import 'package:humsukhan/core/l10n/app_strings.dart';
import 'package:humsukhan/core/theme/app_tokens.dart';
import 'package:humsukhan/domain/professional/professional_session.dart';
import 'package:humsukhan/domain/professional/retention_policy.dart';
import 'package:humsukhan/domain/speech/language_tag.dart';

/// What the user chose when starting a session.
class NewSessionRequest {
  /// Creates a request.
  const NewSessionRequest({
    required this.title,
    required this.type,
    required this.language,
    required this.retentionDays,
  });

  /// What to call it.
  final String title;

  /// Meeting, lecture or class.
  final SessionType type;

  /// The recognition language.
  final LanguageTag language;

  /// How long to keep it.
  final int retentionDays;
}

/// Collects a name, type, language and retention before recording starts.
class NewSessionSheet extends StatefulWidget {
  /// Creates the sheet.
  const NewSessionSheet({
    required this.strings,
    required this.defaultLanguage,
    required this.defaultRetentionDays,
    super.key,
  });

  /// Localised copy.
  final AppStrings strings;

  /// The language pre-selected from settings.
  final LanguageTag defaultLanguage;

  /// The retention pre-selected from settings.
  final int defaultRetentionDays;

  @override
  State<NewSessionSheet> createState() => _NewSessionSheetState();
}

class _NewSessionSheetState extends State<NewSessionSheet> {
  final TextEditingController _title = TextEditingController();
  SessionType _type = SessionType.meeting;
  late LanguageTag _language = widget.defaultLanguage;
  late int _retention = RetentionPolicy(widget.defaultRetentionDays).days;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  StringKey _typeKey(SessionType type) => switch (type) {
    SessionType.meeting => StringKey.proTypeMeeting,
    SessionType.lecture => StringKey.proTypeLecture,
    SessionType.classroom => StringKey.proTypeClass,
  };

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = widget.strings;
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: AppTokens.spaceLg,
        right: AppTokens.spaceLg,
        top: AppTokens.spaceLg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppTokens.spaceLg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            strings(StringKey.proNewSession),
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: AppTokens.spaceMd),
          TextField(
            controller: _title,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: strings(StringKey.proSessionName),
            ),
          ),
          const SizedBox(height: AppTokens.spaceMd),
          Text(
            strings(StringKey.proSessionType),
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: AppTokens.spaceSm),
          Wrap(
            spacing: AppTokens.spaceSm,
            children: SessionType.values
                .map(
                  (SessionType type) => ChoiceChip(
                    label: Text(strings(_typeKey(type))),
                    selected: _type == type,
                    onSelected: (bool _) => setState(() => _type = type),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: AppTokens.spaceMd),
          Text(
            strings(StringKey.proCaptionLanguage),
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: AppTokens.spaceSm),
          Wrap(
            spacing: AppTokens.spaceSm,
            children: LanguageTag.values
                .map(
                  (LanguageTag tag) => ChoiceChip(
                    label: Text(
                      strings(
                        tag == LanguageTag.urdu
                            ? StringKey.setLanguageUrdu
                            : StringKey.setLanguageEnglish,
                      ),
                    ),
                    selected: _language == tag,
                    onSelected: (bool _) => setState(() => _language = tag),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: AppTokens.spaceMd),
          Text(
            strings(StringKey.proRetention),
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: AppTokens.spaceSm),
          Wrap(
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
                    selected: _retention == days,
                    onSelected: (bool _) => setState(() => _retention = days),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: AppTokens.spaceLg),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(strings(StringKey.cancel)),
                ),
              ),
              const SizedBox(width: AppTokens.spaceMd),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(
                    NewSessionRequest(
                      title: _title.text.trim().isEmpty
                          ? strings(_typeKey(_type))
                          : _title.text.trim(),
                      type: _type,
                      language: _language,
                      retentionDays: _retention,
                    ),
                  ),
                  child: Text(strings(StringKey.proStartRecording)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
