import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';

final phiAccessReportProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.get<Map<String, dynamic>>(
    '/compliance/me/phi-access-report',
  );
  return response.data ?? {};
});

class PhiAccessReportScreen extends ConsumerWidget {
  const PhiAccessReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(phiAccessReportProvider);
    final dateFormat = DateFormat.yMMMd().add_jm();

    return AppScaffold(
      title: 'PHI access report',
      body: report.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(
          child: Text('Unable to load PHI access report. Please try again.'),
        ),
        data: (data) {
          final documentAccess =
              data['documentAccess'] as List<dynamic>? ?? [];
          final phiAuditEntries =
              data['phiAuditEntries'] as List<dynamic>? ?? [];

          if (documentAccess.isEmpty && phiAuditEntries.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No PHI access activity has been recorded for your account yet.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'HIPAA §164.528 — accounting of disclosures for your records.',
              ),
              const SizedBox(height: 16),
              if (documentAccess.isNotEmpty) ...[
                const Text(
                  'Document access',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ...documentAccess.map((entry) {
                  final map = entry as Map<String, dynamic>;
                  final accessedAt = DateTime.tryParse(
                    map['accessedAt'] as String? ?? '',
                  );
                  return Card(
                    child: ListTile(
                      title: Text(
                        map['documentTitle'] as String? ?? 'Document',
                      ),
                      subtitle: Text(
                        '${map['action']} · ${accessedAt != null ? dateFormat.format(accessedAt.toLocal()) : 'Unknown time'}',
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 16),
              ],
              if (phiAuditEntries.isNotEmpty) ...[
                const Text(
                  'Clinical data access',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ...phiAuditEntries.map((entry) {
                  final map = entry as Map<String, dynamic>;
                  final createdAt = DateTime.tryParse(
                    map['createdAt'] as String? ?? '',
                  );
                  return Card(
                    child: ListTile(
                      title: Text(
                        '${map['action']} · ${map['resourceType']}',
                      ),
                      subtitle: Text(
                        createdAt != null
                            ? dateFormat.format(createdAt.toLocal())
                            : 'Unknown time',
                      ),
                    ),
                  );
                }),
              ],
            ],
          );
        },
      ),
    );
  }
}
