import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens Stripe Checkout in a new browser tab (web) or external app (mobile).
Future<bool> launchCheckoutUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;

  if (kIsWeb) {
    return launchUrl(uri, webOnlyWindowName: '_blank');
  }

  if (await canLaunchUrl(uri)) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
  return false;
}
