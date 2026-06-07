import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/analytics_date_range.dart';

/// Builds a path/URI string with analytics date-range query params applied.
String analyticsPathWithDateRange(String path, AnalyticsDateRange range) {
  return uriWithAnalyticsDateRange(Uri.parse(path), range).toString();
}

Uri uriWithAnalyticsDateRange(Uri uri, AnalyticsDateRange range) {
  final params = Map<String, String>.from(uri.queryParameters)
    ..remove(analyticsFromDateParam)
    ..remove(analyticsToDateParam)
    ..addAll(range.toQueryParameters());
  return uri.replace(queryParameters: params);
}

/// Keeps [dateRangeProvider] in sync with `fromDate` / `toDate` URL params.
class AnalyticsDateRangeSync extends ConsumerStatefulWidget {
  const AnalyticsDateRangeSync({
    super.key,
    required this.dateRangeProvider,
    required this.child,
  });

  final StateProvider<AnalyticsDateRange> dateRangeProvider;
  final Widget child;

  @override
  ConsumerState<AnalyticsDateRangeSync> createState() =>
      _AnalyticsDateRangeSyncState();
}

class _AnalyticsDateRangeSyncState extends ConsumerState<AnalyticsDateRangeSync> {
  bool _syncingToUrl = false;
  String? _lastAppliedQueryKey;

  String _queryKey(Uri uri) {
    final params = uri.queryParameters;
    return '${params[analyticsFromDateParam]}|${params[analyticsToDateParam]}';
  }

  AnalyticsDateRange _rangeFromUri(Uri uri) =>
      AnalyticsDateRange.fromQueryParameters(uri.queryParameters);

  void _syncFromUri(Uri uri) {
    final key = _queryKey(uri);
    if (key == _lastAppliedQueryKey) return;

    final fromUrl = _rangeFromUri(uri);
    final current = ref.read(widget.dateRangeProvider);
    if (!fromUrl.sameAs(current)) {
      ref.read(widget.dateRangeProvider.notifier).state = fromUrl;
    }
    _lastAppliedQueryKey = key;
  }

  void _syncToUri(AnalyticsDateRange range) {
    if (_syncingToUrl) return;

    final router = GoRouter.of(context);
    final uri = router.state.uri;
    final updated = uriWithAnalyticsDateRange(uri, range);
    if (updated.toString() == uri.toString()) return;

    _syncingToUrl = true;
    _lastAppliedQueryKey = _queryKey(updated);
    router.replace(updated.toString());
    _syncingToUrl = false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_syncingToUrl) {
      _syncFromUri(GoRouterState.of(context).uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uri = GoRouterState.of(context).uri;

    ref.listen<AnalyticsDateRange>(widget.dateRangeProvider, (prev, next) {
      _syncToUri(next);
    });

    if (!_syncingToUrl && _queryKey(uri) != _lastAppliedQueryKey) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_syncingToUrl) {
          _syncFromUri(GoRouterState.of(context).uri);
        }
      });
    }

    return widget.child;
  }
}
