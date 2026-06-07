import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/theme_mode_provider.dart';

class AppThemeToggle extends ConsumerWidget {
  const AppThemeToggle({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(themeModeProvider.notifier);
    final mode = ref.watch(themeModeProvider);

    if (compact) {
      return IconButton(
        tooltip: 'Theme: ${notifier.label} (tap to cycle)',
        icon: Icon(notifier.icon),
        onPressed: notifier.cycleMode,
      );
    }

    return PopupMenuButton<ThemeMode>(
      tooltip: 'Theme: ${notifier.label}',
      icon: Icon(notifier.icon),
      initialValue: mode,
      onSelected: notifier.setMode,
      itemBuilder: (context) => const [
        PopupMenuItem(value: ThemeMode.system, child: Text('System')),
        PopupMenuItem(value: ThemeMode.light, child: Text('Light')),
        PopupMenuItem(value: ThemeMode.dark, child: Text('Dark')),
      ],
    );
  }
}
