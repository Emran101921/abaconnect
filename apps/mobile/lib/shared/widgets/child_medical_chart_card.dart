import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/child_medical_chart_model.dart';

class ChildMedicalChartCard extends StatelessWidget {
  const ChildMedicalChartCard({
    super.key,
    required this.chart,
    this.onTap,
    this.trailing,
  });

  final ChildMedicalChartModel chart;
  final VoidCallback? onTap;
  final Widget? trailing;

  String _formatGender(String? gender) {
    if (gender == null || gender.isEmpty) return '—';
    return gender
        .split('-')
        .map((part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}')
        .join('-');
  }

  String _therapyLabel(String type) {
    switch (type) {
      case 'ABA':
        return 'ABA';
      case 'SPEECH':
        return 'Speech';
      case 'OT':
        return 'OT';
      case 'PT':
        return 'PT';
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFmt = DateFormat.yMMMd();

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: theme.colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                Icon(
                  Icons.medical_information_outlined,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    chart.chartNumber,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                ...chart.therapyTypes.map(
                  (t) => Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Chip(
                      label: Text(_therapyLabel(t)),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  chart.displayName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                _ChartField(
                  label: 'Date of birth',
                  value: dateFmt.format(chart.dateOfBirth),
                ),
                _ChartField(
                  label: 'Sex',
                  value: _formatGender(chart.gender),
                ),
                if (chart.primaryLanguage != null)
                  _ChartField(
                    label: 'Language',
                    value: chart.primaryLanguage!,
                  ),
                _ChartField(
                  label: 'Parent / guardian',
                  value: chart.guardianName ?? chart.parentName,
                ),
                if (chart.pediatricianName != null)
                  _ChartField(
                    label: 'Pediatrician',
                    value: chart.pediatricianName!,
                  ),
                if (chart.insuranceType != null)
                  _ChartField(
                    label: 'Insurance',
                    value: chart.insuranceType!,
                  ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ChartStat(
                      icon: Icons.event_outlined,
                      label: 'Upcoming',
                      value: '${chart.upcomingAppointments}',
                    ),
                    _ChartStat(
                      icon: Icons.check_circle_outline,
                      label: 'Sessions',
                      value: '${chart.completedSessions}',
                    ),
                    _ChartStat(
                      icon: Icons.edit_note_outlined,
                      label: 'Notes due',
                      value: '${chart.pendingDocumentation}',
                      highlight: chart.pendingDocumentation > 0,
                    ),
                  ],
                ),
                if (chart.lastVisitAt != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Last visit ${dateFmt.format(chart.lastVisitAt!)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }
}

class _ChartField extends StatelessWidget {
  const _ChartField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _ChartStat extends StatelessWidget {
  const _ChartStat({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = highlight
        ? theme.colorScheme.errorContainer
        : theme.colorScheme.secondaryContainer;
    final fg = highlight
        ? theme.colorScheme.onErrorContainer
        : theme.colorScheme.onSecondaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(
            '$label: $value',
            style: theme.textTheme.labelMedium?.copyWith(color: fg),
          ),
        ],
      ),
    );
  }
}
