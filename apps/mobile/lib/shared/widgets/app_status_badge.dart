import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Standard status labels used across healthcare workflows.
enum AppStatusKind {
  active,
  pending,
  completed,
  cancelled,
  approved,
  rejected,
  missingDocumentation,
  billingSubmitted,
  paid,
  denied,
  inProgress,
  draft,
}

class AppStatusBadge extends StatelessWidget {
  const AppStatusBadge({
    super.key,
    required this.label,
    this.kind,
    this.color,
    this.backgroundColor,
    this.icon,
    this.compact = true,
  });

  factory AppStatusBadge.fromKind(
    AppStatusKind kind, {
    String? label,
    bool compact = true,
  }) {
    final (text, fg, bg, icon) = _styleFor(kind);
    return AppStatusBadge(
      label: label ?? text,
      kind: kind,
      color: fg,
      backgroundColor: bg,
      icon: icon,
      compact: compact,
    );
  }

  final String label;
  final AppStatusKind? kind;
  final Color? color;
  final Color? backgroundColor;
  final IconData? icon;
  final bool compact;

  static (String, Color, Color, IconData?) _styleFor(AppStatusKind kind) {
    return switch (kind) {
      AppStatusKind.active => (
        'Active',
        AppColors.success,
        const Color(0xFFDCFCE7),
        Icons.check_circle_outline,
      ),
      AppStatusKind.pending => (
        'Pending',
        AppColors.warning,
        const Color(0xFFFEF3C7),
        Icons.schedule_outlined,
      ),
      AppStatusKind.completed => (
        'Completed',
        AppColors.primary,
        const Color(0xFFDBEAFE),
        Icons.task_alt_outlined,
      ),
      AppStatusKind.cancelled => (
        'Cancelled',
        AppColors.textSecondary,
        const Color(0xFFF1F5F9),
        Icons.cancel_outlined,
      ),
      AppStatusKind.approved => (
        'Approved',
        AppColors.success,
        const Color(0xFFDCFCE7),
        Icons.verified_outlined,
      ),
      AppStatusKind.rejected => (
        'Rejected',
        AppColors.error,
        const Color(0xFFFEE2E2),
        Icons.block_outlined,
      ),
      AppStatusKind.missingDocumentation => (
        'Missing documentation',
        AppColors.warning,
        const Color(0xFFFFEDD5),
        Icons.edit_note_outlined,
      ),
      AppStatusKind.billingSubmitted => (
        'Billing submitted',
        AppColors.info,
        const Color(0xFFE0F2FE),
        Icons.receipt_long_outlined,
      ),
      AppStatusKind.paid => (
        'Paid',
        AppColors.accent,
        const Color(0xFFD1FAE5),
        Icons.payments_outlined,
      ),
      AppStatusKind.denied => (
        'Denied',
        AppColors.error,
        const Color(0xFFFEE2E2),
        Icons.error_outline,
      ),
      AppStatusKind.inProgress => (
        'In progress',
        AppColors.secondary,
        const Color(0xFFCCFBF1),
        Icons.autorenew_outlined,
      ),
      AppStatusKind.draft => (
        'Draft',
        AppColors.textSecondary,
        const Color(0xFFF1F5F9),
        Icons.edit_outlined,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final fg = color ?? AppColors.textSecondary;
    final bg = backgroundColor ?? const Color(0xFFF1F5F9);
    final padding = compact
        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
        : const EdgeInsets.symmetric(horizontal: 10, vertical: 6);
    final textStyle = compact
        ? Theme.of(context).textTheme.labelSmall
        : Theme.of(context).textTheme.labelMedium;

    return Semantics(
      label: 'Status: $label',
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          border: Border.all(color: fg.withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: compact ? 14 : 16, color: fg),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: textStyle?.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
