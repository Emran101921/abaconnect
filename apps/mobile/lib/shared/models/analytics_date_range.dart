import 'package:intl/intl.dart';

class AnalyticsDateRange {
  const AnalyticsDateRange({this.from, this.to});

  final DateTime? from;
  final DateTime? to;

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
