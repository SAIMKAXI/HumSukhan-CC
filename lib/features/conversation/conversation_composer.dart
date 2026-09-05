import 'package:flutter/material.dart';
import 'package:humsukhan/core/l10n/app_strings.dart';
import 'package:humsukhan/core/theme/app_tokens.dart';
import 'package:humsukhan/domain/speech/language_policy.dart';

/// The reply field, its Send and Speak buttons, and the quick replies.
///
/// The field follows the *typed* content, not the app language: typing Urdu
/// switches it to right-to-left Nastaliq mid-sentence (design.md §6.3).
class ConversationComposer extends StatefulWidget {
  /// Creates a composer.
  const ConversationComposer({
    required this.strings,
    required this.onSend,
    required this.onSpeak,
    super.key,
    this.locked = false,
    this.lockedReason,
    this.showQuickReplies = true,
  });

  /// Localised copy.
  final AppStrings strings;

  /// Called with the text to add as a caption.
  final ValueChanged<String> onSend;

  /// Called with the text to add and speak aloud.
  final ValueChanged<String> onSpeak;

  /// Whether input is disabled.
  final bool locked;

  /// Why input is disabled, shown next to the disabled controls.
  final String? lockedReason;

  /// Whether the one-tap phrases are offered.
  final bool showQuickReplies;

  /// The phrases offered as one-tap replies.
  static const List<StringKey> quickReplies = <StringKey>[
    StringKey.quickReplyYes,
    StringKey.quickReplyNo,
    StringKey.quickReplyThanks,
    StringKey.quickReplyRepeat,
    StringKey.quickReplySlower,
    StringKey.quickReplyOneMoment,
    StringKey.quickReplyWriteItDown,
  ];

  @override
  State<ConversationComposer> createState() => _ConversationComposerState();
}

class _ConversationComposerState extends State<ConversationComposer> {
  final TextEditingController _controller = TextEditingController();
  ReadingDirection _direction = ReadingDirection.leftToRight;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  void _onChanged() {
    final ReadingDirection next = LanguagePolicy.dominantDirection(
      _controller.text,
    );
    if (next != _direction) setState(() => _direction = next);
  }

  void _submit(ValueChanged<String> action) {
    final String text = _controller.text.trim();
    if (text.isEmpty) return;
    action(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool rtl = _direction == ReadingDirection.rightToLeft;
    final bool hasText = _controller.text.trim().isNotEmpty;
    final bool enabled = !widget.locked;

    return Container(
      padding: const EdgeInsets.all(AppTokens.spaceMd),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(top: BorderSide(color: theme.colorScheme.outline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (widget.showQuickReplies)
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: ConversationComposer.quickReplies.length,
                separatorBuilder: (BuildContext context, int index) =>
                    const SizedBox(width: AppTokens.spaceSm),
                itemBuilder: (BuildContext context, int index) {
                  final StringKey key =
                      ConversationComposer.quickReplies[index];
                  final String label = widget.strings(key);
                  return ActionChip(
                    label: Text(label),
                    onPressed: enabled ? () => widget.onSpeak(label) : null,
                  );
                },
              ),
            ),
          if (widget.showQuickReplies)
            const SizedBox(height: AppTokens.spaceSm),
          if (widget.locked && widget.lockedReason != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppTokens.spaceSm),
              child: Text(
                widget.lockedReason!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 120),
                  child: TextField(
                    controller: _controller,
                    enabled: enabled,
                    minLines: 1,
                    maxLines: 4,
                    textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                    style: TextStyle(
                      fontFamily: rtl
                          ? AppTokens.urduFontFamily
                          : AppTokens.latinFontFamily,
                      height: rtl ? AppTokens.urduLineHeight : null,
                    ),
                    decoration: InputDecoration(
                      hintText: widget.strings(StringKey.everydayComposerHint),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppTokens.spaceSm),
              IconButton.filledTonal(
                tooltip: widget.strings(StringKey.everydaySpeak),
                onPressed: enabled && hasText
                    ? () => _submit(widget.onSpeak)
                    : null,
                icon: const Icon(Icons.volume_up_outlined),
              ),
              const SizedBox(width: AppTokens.spaceXs),
              IconButton.filled(
                tooltip: widget.strings(StringKey.everydaySend),
                onPressed: enabled && hasText
                    ? () => _submit(widget.onSend)
                    : null,
                icon: const Icon(Icons.send),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
