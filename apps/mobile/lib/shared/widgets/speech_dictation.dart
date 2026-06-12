import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/speech_to_text_provider.dart';

/// Mic button that toggles dictation into a [TextEditingController].
class SpeechMicButton extends ConsumerWidget {
  const SpeechMicButton({
    super.key,
    required this.fieldKey,
    required this.controller,
    this.onChanged,
    this.compact = false,
  });

  final String fieldKey;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speech = ref.watch(speechToTextServiceProvider);
    final listening = speech.isListeningFor(fieldKey);
    final theme = Theme.of(context);

    return IconButton(
      visualDensity: compact ? VisualDensity.compact : null,
      tooltip: listening ? 'Stop dictation' : 'Dictate',
      onPressed: () => _toggle(context, ref),
      icon: Icon(
        listening ? Icons.mic : Icons.mic_none_outlined,
        color: listening ? theme.colorScheme.error : theme.colorScheme.primary,
      ),
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    final service = ref.read(speechToTextServiceProvider);
    await service.toggle(
      fieldKey: fieldKey,
      currentText: controller.text,
      onUpdate: (text) {
        controller.text = text;
        controller.selection = TextSelection.collapsed(offset: text.length);
        onChanged?.call(text);
      },
    );

    if (!context.mounted) return;
    final error = ref.read(speechToTextServiceProvider).lastError;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dictation unavailable: $error')),
      );
    } else if (!ref.read(speechToTextServiceProvider).isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Speech recognition is not available. Check microphone permissions.',
          ),
        ),
      );
    }
  }
}

/// [TextField] with a built-in dictation mic in the suffix.
class SpeechDictationTextField extends StatelessWidget {
  const SpeechDictationTextField({
    super.key,
    required this.fieldKey,
    required this.controller,
    this.decoration,
    this.maxLines = 1,
    this.minLines,
    this.onChanged,
    this.readOnly = false,
  });

  final String fieldKey;
  final TextEditingController controller;
  final InputDecoration? decoration;
  final int? maxLines;
  final int? minLines;
  final ValueChanged<String>? onChanged;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final base = decoration ?? const InputDecoration();
    return TextField(
      controller: controller,
      readOnly: readOnly,
      maxLines: maxLines,
      minLines: minLines,
      onChanged: onChanged,
      decoration: base.copyWith(
        suffixIcon: readOnly
            ? base.suffixIcon
            : SpeechMicButton(
                fieldKey: fieldKey,
                controller: controller,
                onChanged: onChanged,
                compact: true,
              ),
      ),
    );
  }
}
