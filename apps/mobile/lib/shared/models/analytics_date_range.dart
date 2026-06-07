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
