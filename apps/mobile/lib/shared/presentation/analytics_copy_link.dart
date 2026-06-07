import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

/// Resolves the shareable URL for the current analytics route.
String analyticsShareableUrl(BuildContext context) {
  final uri = GoRouter.of(context).state.uri;
  if (kIsWeb) {
    return Uri.base.resolve(uri.toString()).toString();
  }
  return uri.toString();
}

Future<void> copyAnalyticsLink(BuildContext context) async {
  final url = analyticsShareableUrl(context);
  await Clipboard.setData(ClipboardData(text: url));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copied')),
    );
  }
}

class AnalyticsCopyLinkButton extends StatelessWidget {
  const AnalyticsCopyLinkButton({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();

    return IconButton(
      icon: const Icon(Icons.link),
      tooltip: 'Copy link',
      onPressed: () => copyAnalyticsLink(context),
    );
  }
}
