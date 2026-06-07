import 'package:intl/intl.dart';

const analyticsFromDateParam = 'fromDate';
const analyticsToDateParam = 'toDate';

class AnalyticsDateRange {
  const AnalyticsDateRange({this.from, this.to});

  final DateTime? from;
  final DateTime? to;

  factory AnalyticsDateRange.fromQueryParameters(
    Map<String, String> params,
  ) {
    return AnalyticsDateRange(
      from: _parseQueryDate(params[analyticsFromDateParam]),
      to: _parseQueryDate(params[analyticsToDateParam]),
    );
  }

  static DateTime? _parseQueryDate(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  Map<String, String> toQueryParameters() {
    if (!isActive) return const {};
    final params = <String, String>{};
    final fromValue = graphqlFrom;
    final toValue = graphqlTo;
    if (fromValue != null) params[analyticsFromDateParam] = fromValue;
    if (toValue != null) params[analyticsToDateParam] = toValue;
    return params;
  }

  bool sameAs(AnalyticsDateRange other) =>
      graphqlFrom == other.graphqlFrom && graphqlTo == other.graphqlTo;

  bool get isActive => from != null || to != null;

  String? get graphqlFrom =>
      from != null ? DateFormat('yyyy-MM-dd').format(from!) : null;

  String? get graphqlTo =>
      to != null ? DateFormat('yyyy-MM-dd').format(to!) : null;

  String get label {
    if (!isActive) return 'All dates';
    final fmt = DateFormat.yMMMd();
    if (from != null && to != null) {
      return '${fmt.format(from!)} – ${fmt.format(to!)}';
    }
    if (from != null) return 'From ${fmt.format(from!)}';
    return 'Through ${fmt.format(to!)}';
  }

  String get filenameSuffix {
    if (!isActive) return '';
    final fmt = DateFormat('yyyy-MM-dd');
    final fromPart = from != null ? fmt.format(from!) : 'start';
    final toPart = to != null ? fmt.format(to!) : 'end';
    return '-$fromPart-$toPart';
  }
}

DateTime analyticsDateOnly(DateTime date) =>
    DateTime(date.year, date.month, date.day);

DateTime get analyticsToday => analyticsDateOnly(DateTime.now());

const analyticsDefaultDateRangePreset = AnalyticsDateRangePreset.last30Days;

enum AnalyticsDateRangePreset {
  last7Days('Last 7 days'),
  last30Days('Last 30 days'),
  thisMonth('This month'),
  lastMonth('Last month');

  const AnalyticsDateRangePreset(this.label);

  final String label;

  AnalyticsDateRange get range {
    final today = analyticsToday;
    switch (this) {
      case AnalyticsDateRangePreset.last7Days:
        return AnalyticsDateRange(
          from: today.subtract(const Duration(days: 6)),
          to: today,
        );
      case AnalyticsDateRangePreset.last30Days:
        return AnalyticsDateRange(
          from: today.subtract(const Duration(days: 29)),
          to: today,
        );
      case AnalyticsDateRangePreset.thisMonth:
        return AnalyticsDateRange(
          from: DateTime(today.year, today.month),
          to: today,
        );
      case AnalyticsDateRangePreset.lastMonth:
        final firstOfThisMonth = DateTime(today.year, today.month);
        final lastOfLastMonth =
            firstOfThisMonth.subtract(const Duration(days: 1));
        return AnalyticsDateRange(
          from: DateTime(lastOfLastMonth.year, lastOfLastMonth.month),
          to: lastOfLastMonth,
        );
    }
  }

  bool matches(AnalyticsDateRange range) => range.sameAs(this.range);
}

String analyticsOverviewMetricLabel(
  String key,
  AnalyticsDateRange range, {
  String activeChildrenLabel = 'Active children',
}) {
  switch (key) {
    case 'appointments_7d':
      return range.isActive ? 'Appointments' : 'Appointments (30d)';
    case 'sessions_completed':
      return 'Sessions completed';
    case 'revenue_paid':
      return 'Revenue paid';
    case 'claims_paid_total':
      return 'Claims paid total';
    case 'revenue_mismatch':
      return 'Revenue mismatch';
    case 'active_children':
      return activeChildrenLabel;
    default:
      return key;
  }
}
