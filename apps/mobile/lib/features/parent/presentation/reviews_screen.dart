import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../data/parent_booking_repository.dart';

class ReviewsScreen extends ConsumerStatefulWidget {
  const ReviewsScreen({super.key});

  @override
  ConsumerState<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends ConsumerState<ReviewsScreen> {
  List<ReviewModel> _reviews = [];
  List<TherapistModel> _therapists = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final repo = ref.read(parentBookingRepositoryProvider);
    try {
      final reviews = await repo.fetchReviews();
      final therapists = await repo.fetchTherapists();
      if (mounted) {
        setState(() {
          _reviews = reviews;
          _therapists = therapists;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load reviews: $e')),
        );
      }
    }
  }

  Future<void> _submitReview() async {
    if (_therapists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No therapists available to review')),
      );
      return;
    }
    var therapistId = _therapists.first.id;
    var rating = 5;
    final comment = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('Leave a review'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: therapistId,
                decoration: const InputDecoration(labelText: 'Therapist'),
                items: _therapists
                    .map(
                      (t) => DropdownMenuItem(
                        value: t.id,
                        child: Text(t.displayName),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setDialog(() => therapistId = v!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: rating,
                decoration: const InputDecoration(labelText: 'Rating'),
                items: List.generate(
                  5,
                  (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1} stars')),
                ),
                onChanged: (v) => setDialog(() => rating = v!),
              ),
              TextField(
                controller: comment,
                decoration: const InputDecoration(labelText: 'Comment'),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Submit')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(parentBookingRepositoryProvider).submitReview(
            therapistId: therapistId,
            rating: rating,
            comment: comment.text.trim().isEmpty ? null : comment.text.trim(),
          );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Review submitted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submit failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Reviews',
      floatingActionButton: FloatingActionButton(
        onPressed: _submitReview,
        child: const Icon(Icons.rate_review),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _reviews.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('No reviews yet.'),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _submitReview,
                        child: const Text('Write first review'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _reviews.length,
                    separatorBuilder: (context, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final r = _reviews[index];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.therapistName,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: List.generate(
                                  5,
                                  (i) => Icon(
                                    i < r.rating ? Icons.star : Icons.star_border,
                                    color: Colors.amber,
                                    size: 20,
                                  ),
                                ),
                              ),
                              if (r.comment != null && r.comment!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(r.comment!),
                              ],
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
