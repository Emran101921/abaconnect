import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../parent/data/parent_booking_repository.dart';

class MatchResultsScreen extends ConsumerStatefulWidget {
  const MatchResultsScreen({super.key, this.therapyTypes});

  final List<String>? therapyTypes;

  @override
  ConsumerState<MatchResultsScreen> createState() => _MatchResultsScreenState();
}

class _MatchResultsScreenState extends ConsumerState<MatchResultsScreen> {
  List<TherapistModel> _therapists = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await ref.read(parentBookingRepositoryProvider).fetchTherapists(
            therapyTypes: widget.therapyTypes,
          );
      if (mounted) {
        setState(() {
          _therapists = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Match load failed: $e')),
        );
      }
    }
  }

  String get _filterLabel {
    final types = widget.therapyTypes;
    if (types == null || types.isEmpty) return 'All services';
    return types.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Matched Therapists',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.therapyTypes != null && widget.therapyTypes!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Card(
                child: ListTile(
                  leading: const Icon(Icons.filter_alt_outlined),
                  title: const Text('Filtered by recommended services'),
                  subtitle: Text(_filterLabel),
                ),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _therapists.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            widget.therapyTypes != null &&
                                    widget.therapyTypes!.isNotEmpty
                                ? 'No therapists found for $_filterLabel in your area.'
                                : 'No therapists found for your area.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _therapists.length,
                          separatorBuilder: (context, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final t = _therapists[index];
                            final matchPct = t.matchScore != null
                                ? '${(t.matchScore! * 100).round()}% match'
                                : 'Recommended';
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          child: Text(
                                            t.displayName.characters.first,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                t.displayName,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium,
                                              ),
                                              Text(
                                                '★ ${t.rating.toStringAsFixed(1)} · $matchPct',
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    FilledButton(
                                      onPressed: () =>
                                          context.push(AppRoutes.parentBooking),
                                      child: const Text('Book session'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
