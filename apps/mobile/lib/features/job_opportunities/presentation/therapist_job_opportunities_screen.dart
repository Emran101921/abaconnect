import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/layout/action_button.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../../../shared/widgets/role_tab_scaffold.dart';
import '../data/job_opportunities_repository.dart';
import '../widgets/job_opportunity_card.dart';
import '../widgets/phi_warning_banner.dart';

class TherapistJobOpportunitiesScreen extends ConsumerStatefulWidget {
  const TherapistJobOpportunitiesScreen({
    super.key,
    this.initialSearchQuery,
    this.initialZipCode,
  });

  final String? initialSearchQuery;
  final String? initialZipCode;

  @override
  ConsumerState<TherapistJobOpportunitiesScreen> createState() =>
      _TherapistJobOpportunitiesScreenState();
}

class _TherapistJobOpportunitiesScreenState
    extends ConsumerState<TherapistJobOpportunitiesScreen> {
  late final TextEditingController _zipController;
  late final TextEditingController _searchController;
  String? _serviceType;
  List<JobOpportunityModel> _items = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _zipController = TextEditingController(text: widget.initialZipCode ?? '');
    _searchController =
        TextEditingController(text: widget.initialSearchQuery ?? '');
    WidgetsBinding.instance.addPostFrameCallback((_) => _search());
  }

  @override
  void dispose() {
    _zipController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<JobOpportunityModel> _filterBySearchQuery(
    List<JobOpportunityModel> items,
  ) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return items;
    return items.where((job) {
      final haystack = [
        job.title,
        job.serviceTypeLabel,
        job.locationAreaLabel,
        job.agencyName,
        job.publicDescription,
      ].whereType<String>().join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
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
      setState(() => _items = _filterBySearchQuery(items));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final invitesAsync = ref.watch(therapistJobInvitesProvider);

    return TherapistTabScaffold(
      title: 'Job Opportunities',
      subtitle: 'Agency staffing posts — separate from parent referrals',
      actions: [
        ActionButton(
          label: 'Saved jobs',
          icon: Icons.bookmark_outline,
          onPressed: () => context.push(AppRoutes.therapistSavedJobs),
          variant: GlossyButtonVariant.secondary,
          fullWidth: false,
          size: GlossyButtonSize.medium,
        ),
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
          invitesAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (invites) {
              if (invites.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.mail_outline, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Agency invites (${invites.length})',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const PhiWarningBanner(compact: true),
                        const SizedBox(height: 8),
                        ...invites.map(
                          (invite) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(invite.jobTitle),
                            subtitle: Text(
                              '${invite.agencyName} · invited '
                              '${invite.invitedAt.toLocal().toString().split('.').first}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.push(
                              '${AppRoutes.therapistJobOpportunities}/${invite.jobOpportunityId}',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          labelText: 'Search listings',
                          hintText: 'Title, agency, service type…',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onSubmitted: (_) => _search(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
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
                          : const Icon(Icons.filter_alt_outlined),
                    ),
                  ],
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
