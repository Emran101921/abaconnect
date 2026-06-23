import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_select.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../data/parent_booking_repository.dart';
import 'parent_dashboard_providers.dart';

class ReviewsScreen extends ConsumerStatefulWidget {
  const ReviewsScreen({
    super.key,
    this.initialTherapistId,
    this.autoOpenSubmit = false,
  });

  final String? initialTherapistId;
  final bool autoOpenSubmit;

  @override
  ConsumerState<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends ConsumerState<ReviewsScreen> {
  List<ReviewModel> _reviews = [];
  List<TherapistModel> _pendingTherapists = [];
  bool _loading = true;
  bool _autoOpened = false;

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
      final pending = await repo.fetchPendingReviewTherapists();
      if (mounted) {
        setState(() {
          _reviews = reviews;
          _pendingTherapists = pending;
          _loading = false;
        });
        _maybeAutoOpenSubmit();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load reviews: $e')));
      }
    }
  }

  void _maybeAutoOpenSubmit() {
    if (_autoOpened || !widget.autoOpenSubmit || _pendingTherapists.isEmpty) {
      return;
    }
    _autoOpened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _submitReview();
    });
  }

  Future<void> _submitReview() async {
    if (_pendingTherapists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No completed sessions awaiting a therapist review'),
        ),
      );
      return;
    }
    final initialId = widget.initialTherapistId;
    var therapistId = _pendingTherapists.any((t) => t.id == initialId)
        ? initialId!
        : _pendingTherapists.first.id;
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
              AppSelectField<String>(
                label: 'Therapist',
                value: therapistId,
                searchHint: _pendingTherapists.length > 6 ? 'Search' : null,
                options: _pendingTherapists
                    .map(
                      (t) => AppSelectOption(
                        value: t.id,
                        label: t.displayName,
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setDialog(() => therapistId = v);
                },
              ),
              const SizedBox(height: 12),
              AppSelectField<int>(
                label: 'Rating',
                value: rating,
                options: List.generate(
                  5,
                  (i) => AppSelectOption(
                    value: i + 1,
                    label: '${i + 1} stars',
                  ),
                ),
                onChanged: (v) {
                  if (v != null) setDialog(() => rating = v);
                },
              ),
              TextField(
                controller: comment,
                decoration: const InputDecoration(labelText: 'Comment'),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            GlossyButton(
              title: 'Submit',
              size: GlossyButtonSize.small,
              fullWidth: false,
              variant: GlossyButtonVariant.greenTeal,
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(parentBookingRepositoryProvider)
          .submitReview(
            therapistId: therapistId,
            rating: rating,
            comment: comment.text.trim().isEmpty ? null : comment.text.trim(),
          );
      ref.invalidate(parentPendingReviewsProvider);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Review submitted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Submit failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Reviews',
      floatingActionButton: _pendingTherapists.isEmpty
          ? null
          : GlossyFab(
              icon: Icons.rate_review,
              onPressed: _submitReview,
              tooltip: 'Submit review',
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_pendingTherapists.isNotEmpty)
                  MaterialBanner(
                    content: Text(
                      '${_pendingTherapists.length} therapist(s) awaiting your review',
                    ),
                    leading: const Icon(Icons.rate_review),
                    actions: [
                      TextButton(
                        onPressed: _submitReview,
                        child: const Text('Review now'),
                      ),
                    ],
                  ),
                Expanded(
                  child: _reviews.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _pendingTherapists.isEmpty
                                    ? 'No reviews yet.'
                                    : 'No reviews submitted yet.',
                              ),
                              if (_pendingTherapists.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                GlossyButton(
                                  title: 'Write first review',
                                  variant: GlossyButtonVariant.bluePurple,
                                  onPressed: _submitReview,
                                ),
                              ],
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _reviews.length,
                            separatorBuilder: (context, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final r = _reviews[index];
                              return Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        r.therapistName,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: List.generate(
                                          5,
                                          (i) => Icon(
                                            i < r.rating
                                                ? Icons.star
                                                : Icons.star_border,
                                            color: Colors.amber,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                      if (r.comment != null &&
                                          r.comment!.isNotEmpty) ...[
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
                ),
              ],
            ),
    );
  }
}
