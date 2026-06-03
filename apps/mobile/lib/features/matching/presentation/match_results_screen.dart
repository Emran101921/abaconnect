import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../parent/data/parent_booking_repository.dart';

class MatchResultsScreen extends ConsumerStatefulWidget {
  const MatchResultsScreen({super.key});

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
    try {
      final list =
          await ref.read(parentBookingRepositoryProvider).fetchTherapists();
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

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Matched Therapists',
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _therapists.isEmpty
              ? const Center(child: Text('No therapists found for your area.'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _therapists.length,
                    separatorBuilder: (context, _) => const SizedBox(height: 12),
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
                                    child: Text(t.displayName.characters.first),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
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
    );
  }
}
