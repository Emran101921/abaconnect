import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/glossy_button.dart';
import 'admin_providers.dart';

class AdminReviewsScreen extends ConsumerWidget {
  const AdminReviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviews = ref.watch(adminReviewsProvider);

    return AppScaffold(
      title: 'Review moderation',
      body: reviews.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No reviews yet'));
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(adminReviewsProvider);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final r = list[index];
                final stars = List.filled(r.rating.clamp(1, 5), '★').join();
                return Card(
                  child: ListTile(
                    title: Text('${r.therapistName ?? 'Therapist'} · $stars'),
                    subtitle: Text(
                      '${r.authorEmail ?? ''}\n'
                      '${r.isPublished ? 'Published' : 'Hidden'}\n'
                      '${r.comment ?? r.title ?? ''}',
                    ),
                    isThreeLine: true,
                    trailing: r.isPublished
                        ? GlossyOutlinedButton(
                            onPressed: () =>
                                _moderate(context, ref, r.id, false),
                            child: const Text('Hide'),
                          )
                        : GlossyButton(
                            title: 'Publish',
                            size: GlossyButtonSize.small,
                            fullWidth: false,
                            variant: GlossyButtonVariant.greenTeal,
                            onPressed: () =>
                                _moderate(context, ref, r.id, true),
                          ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _moderate(
    BuildContext context,
    WidgetRef ref,
    String id,
    bool publish,
  ) async {
    try {
      await ref.read(adminRepositoryProvider).moderateReview(id, publish);
      ref.invalidate(adminReviewsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(publish ? 'Review published' : 'Review hidden'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }
}
