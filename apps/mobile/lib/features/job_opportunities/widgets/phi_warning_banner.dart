import 'package:flutter/material.dart';

import '../../../shared/widgets/app_trust_notice.dart';

class PhiWarningBanner extends StatelessWidget {
  const PhiWarningBanner({
    super.key,
    this.message,
    this.compact = false,
  });

  final String? message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AppTrustNotice(
      dense: compact,
      icon: Icons.shield_outlined,
      message: message ??
          'Do not include child names, diagnoses, referral details, or addresses in public job descriptions.',
    );
  }
}
