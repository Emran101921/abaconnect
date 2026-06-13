import 'package:flutter/material.dart';

abstract final class AppSnackBar {
  static void showError(BuildContext context, String message) {
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: scheme.onErrorContainer),
        ),
        backgroundColor: scheme.errorContainer,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static void showSuccess(BuildContext context, String message) {
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: scheme.primaryContainer,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static String messageFromError(Object error) {
    final raw = error.toString();
    const prefix = 'Exception: ';
    if (raw.startsWith(prefix)) {
      return raw.substring(prefix.length);
    }
    return raw;
  }
}
