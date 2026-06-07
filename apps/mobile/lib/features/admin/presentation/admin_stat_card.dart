import 'package:flutter/material.dart';

import '../../../shared/widgets/app_stat_card.dart';

class AdminStatCard extends StatelessWidget {
  const AdminStatCard({
    super.key,
    required this.label,
    required this.value,
    this.periodDelta,
    this.highlight = false,
    this.onTap,
  });

  final String label;
  final Object value;
  final String? periodDelta;
  final bool highlight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppStatCard(
      label: label,
      value: value,
      periodDelta: periodDelta,
      highlight: highlight,
      onTap: onTap,
    );
  }
}
