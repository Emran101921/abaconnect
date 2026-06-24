import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/router/app_router.dart';
import '../../../shared/widgets/glossy_button.dart';

/// Whether [joinUrl] should open in the in-app Daily WebView.
bool isDailyTelehealthJoinUrl(String joinUrl, {String? vendor}) {
  if (vendor == 'daily') return true;
  return joinUrl.contains('daily.co');
}

/// Opens a Daily room in-app; otherwise shows copy-link / external launch fallback.
void openTelehealthJoinUrl(
  BuildContext context, {
  required String joinUrl,
  String? title,
  String? vendor,
}) {
  if (isDailyTelehealthJoinUrl(joinUrl, vendor: vendor)) {
    final uri = Uri(
      path: '${AppRoutes.telehealth}/room',
      queryParameters: {
        'url': joinUrl,
        if (title != null && title.isNotEmpty) 'title': title,
        if (vendor != null && vendor.isNotEmpty) 'vendor': vendor,
      },
    );
    context.push(uri.toString());
    return;
  }
  showTelehealthRoomLinkDialog(context, joinUrl);
}

void showTelehealthRoomLinkDialog(BuildContext context, String url) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Session link'),
      content: SelectableText(url),
      actions: [
        TextButton(
          onPressed: () async {
            final uri = Uri.tryParse(url);
            if (uri == null) return;
            final launched = await launchUrl(
              uri,
              mode: LaunchMode.externalApplication,
            );
            if (launched && ctx.mounted) {
              Navigator.pop(ctx);
            }
          },
          child: const Text('Open in browser'),
        ),
        TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: url));
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Link copied')),
            );
          },
          child: const Text('Copy link'),
        ),
        GlossyButton(
          title: 'Close',
          size: GlossyButtonSize.small,
          fullWidth: false,
          variant: GlossyButtonVariant.neutral,
          onPressed: () => Navigator.pop(ctx),
        ),
      ],
    ),
  );
}
