import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../shared/layout/action_button.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../../../shared/widgets/role_tab_scaffold.dart';
import '../data/job_opportunities_repository.dart';
import '../widgets/job_opportunity_card.dart';

class TherapistJobOpportunitiesScreen extends ConsumerStatefulWidget {
  const TherapistJobOpportunitiesScreen({super.key});

  @override
  ConsumerState<TherapistJobOpportunitiesScreen> createState() =>
      _TherapistJobOpportunitiesScreenState();
}

class _TherapistJobOpportunitiesScreenState
    extends ConsumerState<TherapistJobOpportunitiesScreen> {
  final _zipController = TextEditingController();
  String? _serviceType;
  List<JobOpportunityModel> _items = [];
  bool _loading = false;

  @override
  void dispose() {
    _zipController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() => _loading = true);
    try {
      final items = await ref
          .read(jobOpportunitiesRepositoryProvider)
          .browseJobOpportunities(
            zipCode: _zipController.text.trim(),
            serviceType: _serviceType,
            radiusMiles: 25,
          );
      setState(() => _items = items);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _search());
  }

  @override
  Widget build(BuildContext context) {
    return TherapistTabScaffold(
      title: 'Job Opportunities',
      subtitle: 'Agency staffing posts — separate from parent referrals',
      actions: [
        ActionButton(
          label: 'My applications',
          icon: Icons.assignment_outlined,
          onPressed: () => context.push(AppRoutes.therapistJobApplications),
          variant: GlossyButtonVariant.secondary,
          fullWidth: false,
          size: GlossyButtonSize.medium,
        ),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _zipController,
                    decoration: const InputDecoration(
                      labelText: 'ZIP code',
                      hintText: '11201',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String?>(
                  value: _serviceType,
                  hint: const Text('Service'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All')),
                    ...const [
                      'ABA',
                      'OT',
                      'PT',
                      'SPEECH',
                      'SPECIAL_INSTRUCTION',
                    ].map(
                      (t) => DropdownMenuItem(value: t, child: Text(t)),
                    ),
                  ],
                  onChanged: (v) => setState(() => _serviceType = v),
                ),
                IconButton(
                  onPressed: _loading ? null : _search,
                  icon: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                ),
              ],
            ),
          ),
          Expanded(
            child: _items.isEmpty
                ? const Center(child: Text('No published opportunities match.'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final job = _items[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: JobOpportunityCard(
                          opportunity: job,
                          onTap: () => context.push(
                            '${AppRoutes.therapistJobOpportunities}/${job.id}',
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
