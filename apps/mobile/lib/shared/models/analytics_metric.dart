class AnalyticsMetricModel {
  const AnalyticsMetricModel({
    required this.metricKey,
    required this.metricValue,
    this.priorPeriodValue,
  });

  final String metricKey;
  final double metricValue;
  final double? priorPeriodValue;

  bool get hasPeriodComparison => priorPeriodValue != null;
}

const analyticsOverviewComparisonKeys = {
  'appointments_7d',
  'sessions_completed',
  'revenue_paid',
  'claims_paid_total',
  'active_children',
};

const analyticsReconciliationKeys = {
  'revenue_paid',
  'claims_paid_total',
  'revenue_mismatch',
};

String formatCountPeriodDelta(int current, int prior) =>
    formatAnalyticsPeriodDelta(current.toDouble(), prior.toDouble());

String formatAnalyticsPeriodDelta(
  double current,
  double? prior, {
  bool isCurrency = false,
}) {
  if (prior == null) return '—';
  if (current == prior) return '—';

  if (prior == 0) {
    if (current == 0) return '—';
    if (isCurrency) {
      final sign = current > 0 ? '+' : '';
      return '$sign${current.toStringAsFixed(0)}';
    }
    final sign = current > 0 ? '+' : '';
    return '$sign${current.toStringAsFixed(0)}';
  }

  final pct = ((current - prior) / prior) * 100;
  final sign = pct >= 0 ? '+' : '';
  final decimals = isCurrency ? 1 : 0;
  return '$sign${pct.toStringAsFixed(decimals)}%';
}
