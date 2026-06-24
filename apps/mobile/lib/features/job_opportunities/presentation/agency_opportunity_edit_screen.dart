import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../data/job_opportunities_repository.dart';
import '../widgets/phi_warning_banner.dart';

final agencyJobOpportunityProvider =
    FutureProvider.family<JobOpportunityModel?, String>((ref, jobId) async {
  final jobs =
      await ref.watch(agencyJobOpportunitiesProvider.future);
  try {
    return jobs.firstWhere((job) => job.id == jobId);
  } catch (_) {
    return null;
  }
});

class AgencyOpportunityEditScreen extends ConsumerStatefulWidget {
  const AgencyOpportunityEditScreen({super.key, required this.jobOpportunityId});

  final String jobOpportunityId;

  @override
  ConsumerState<AgencyOpportunityEditScreen> createState() =>
      _AgencyOpportunityEditScreenState();
}

class _AgencyOpportunityEditScreenState
    extends ConsumerState<AgencyOpportunityEditScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _payRateController = TextEditingController();
  bool _loaded = false;
  bool _saving = false;
  bool _publishing = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _payRateController.dispose();
    super.dispose();
  }

  void _fill(JobOpportunityModel job) {
    if (_loaded) return;
    _titleController.text = job.title;
    _descriptionController.text = job.publicDescription ?? '';
    _payRateController.text = job.payRateDisplay ?? '';
    _loaded = true;
  }

  Future<void> _saveDraft() async {
    setState(() => _saving = true);
    try {
      await ref.read(jobOpportunitiesRepositoryProvider).updateJobOpportunity(
            jobOpportunityId: widget.jobOpportunityId,
            title: _titleController.text.trim(),
            publicDescription: _descriptionController.text.trim(),
            payRateDisplay: _payRateController.text.trim().isEmpty
                ? null
                : _payRateController.text.trim(),
          );
      ref.invalidate(agencyJobOpportunitiesProvider);
      ref.invalidate(agencyJobOpportunityProvider(widget.jobOpportunityId));
      if (mounted) {
        AppSnackBar.showSuccess(context, 'Draft saved');
      }
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _publish() async {
    setState(() => _publishing = true);
    try {
      await ref.read(jobOpportunitiesRepositoryProvider).updateJobOpportunity(
            jobOpportunityId: widget.jobOpportunityId,
            title: _titleController.text.trim(),
            publicDescription: _descriptionController.text.trim(),
            payRateDisplay: _payRateController.text.trim().isEmpty
                ? null
                : _payRateController.text.trim(),
          );
      await ref
          .read(jobOpportunitiesRepositoryProvider)
          .publishJobOpportunity(widget.jobOpportunityId);
      ref.invalidate(agencyJobOpportunitiesProvider);
      ref.invalidate(agencyJobOpportunityProvider(widget.jobOpportunityId));
      ref.invalidate(agencyChildServiceNeedsProvider);
      if (mounted) {
        AppSnackBar.showSuccess(context, 'Job opportunity published');
      }
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, e);
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final jobAsync = ref.watch(agencyJobOpportunityProvider(widget.jobOpportunityId));

    return jobAsync.when(
      loading: () => AppScaffold(
        title: 'Job posting',
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => AppScaffold(
        title: 'Job posting',
        body: Center(child: Text(AppSnackBar.messageFromError(e))),
      ),
      data: (job) {
        if (job == null) {
          return AppScaffold(
            title: 'Job posting',
            body: const Center(child: Text('Posting not found')),
          );
        }
        _fill(job);
        final canPublish =
            job.status == 'DRAFT' || job.status == 'PAUSED' || job.status == 'BLOCKED';

        return AppScaffold(
          title: 'Edit job posting',
          subtitle: job.status,
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const PhiWarningBanner(),
              const SizedBox(height: 16),
              Text(
                'Review public text before publishing. PHI is blocked automatically.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Public title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Public description',
                  alignLabelWithHint: true,
                  hintText:
                      'Describe the role and setting without child names, diagnoses, or identifiers.',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _payRateController,
                decoration: const InputDecoration(
                  labelText: 'Pay rate display (optional)',
                  hintText: r'e.g. $45-55/hr',
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${job.serviceTypeLabel} · ${job.locationAreaLabel}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              GlossyButton(
                label: 'Save draft',
                loading: _saving && !_publishing,
                onPressed: _saving || _publishing ? null : _saveDraft,
              ),
              if (canPublish) ...[
                const SizedBox(height: 12),
                GlossyButton(
                  label: 'Publish posting',
                  variant: GlossyButtonVariant.greenTeal,
                  loading: _publishing,
                  onPressed: _saving || _publishing ? null : _publish,
                ),
              ],
              const SizedBox(height: 12),
              GlossyButton(
                label: 'View applicants',
                variant: GlossyButtonVariant.secondary,
                onPressed: () => context.push(
                  '${AppRoutes.agencyOpportunities}/${widget.jobOpportunityId}/applicants',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
