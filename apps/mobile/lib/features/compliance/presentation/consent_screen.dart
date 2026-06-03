import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../platform/data/platform_repository.dart';

final consentsProvider = FutureProvider<List<ConsentItemModel>>((ref) {
  return ref.watch(platformRepositoryProvider).fetchConsents();
});

class ConsentScreen extends ConsumerWidget {
  const ConsentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consents = ref.watch(consentsProvider);

    return AppScaffold(
      title: 'Privacy & consent',
      body: consents.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'HIPAA consents required to use clinical features. '
              'Grant the latest policy version below.',
            ),
            const SizedBox(height: 16),
            ...list.map(
              (c) => Card(
                child: ListTile(
                  title: Text(c.consentType),
                  subtitle: Text('Version ${c.version}'),
                  trailing: Icon(
                    c.granted ? Icons.check_circle : Icons.cancel,
                    color: c.granted ? Colors.green : Colors.grey,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                try {
                  await ref.read(platformRepositoryProvider).grantConsent(
                        'HIPAA_PRIVACY',
                        '1.0',
                      );
                  ref.invalidate(consentsProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Consent granted')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$e'),
                    );
                  }
                }
              },
              child: const Text('Grant HIPAA privacy policy v1.0'),
            ),
          ],
        ),
      ),
    );
  }
}
