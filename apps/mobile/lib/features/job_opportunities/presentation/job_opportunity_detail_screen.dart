import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../data/job_opportunities_repository.dart';
import '../widgets/phi_warning_banner.dart';

class JobOpportunityDetailScreen extends ConsumerStatefulWidget {
  const JobOpportunityDetailScreen({super.key, required this.jobOpportunityId});

  final String jobOpportunityId;

  @override
  ConsumerState<JobOpportunityDetailScreen> createState() =>
      _JobOpportunityDetailScreenState();
}

class _JobOpportunityDetailScreenState
    extends ConsumerState<JobOpportunityDetailScreen> {
  final _messageController = TextEditingController();
  bool _applying = false;
  bool _saving = false;
  bool? _isSaved;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    setState(() => _applying = true);
    try {
      await ref.read(jobOpportunitiesRepositoryProvider).applyToJobOpportunity(
            jobOpportunityId: widget.jobOpportunityId,
            message: _messageController.text.trim().isEmpty
                ? null
                : _messageController.text.trim(),
          );
      if (mounted) AppSnackBar.showSuccess(context, 'Application submitted');
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, e);
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  Future<void> _toggleSaved(bool currentlySaved) async {
    setState(() => _saving = true);
    try {
      final repo = ref.read(jobOpportunitiesRepositoryProvider);
      if (currentlySaved) {
        await repo.unsaveJobOpportunity(widget.jobOpportunityId);
        if (mounted) {
          setState(() => _isSaved = false);
          AppSnackBar.showSuccess(context, 'Removed from saved jobs');
        }
      } else {
        await repo.saveJobOpportunity(widget.jobOpportunityId);
        if (mounted) {
          setState(() => _isSaved = true);
          AppSnackBar.showSuccess(context, 'Saved job');
        }
      }
      ref.invalidate(therapistSavedJobsProvider);
      ref.invalidate(therapistJobOpportunityProvider(widget.jobOpportunityId));
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final jobAsync =
        ref.watch(therapistJobOpportunityProvider(widget.jobOpportunityId));

    return jobAsync.when(
      loading: () => const AppScaffold(
        title: 'Job opportunity',
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => AppScaffold(
        title: 'Job opportunity',
        body: Center(child: Text('$e')),
      ),
      data: (job) {
        if (job == null) {
          return const AppScaffold(
            title: 'Job opportunity',
            body: Center(child: Text('Opportunity not found')),
          );
        }

        final isSaved = _isSaved ?? job.isSaved ?? false;

        return AppScaffold(
          title: job.title,
          subtitle: job.agencyName ?? job.locationAreaLabel,
          actions: [
            IconButton(
              tooltip: isSaved ? 'Remove from saved' : 'Save job',
              onPressed: _saving ? null : () => _toggleSaved(isSaved),
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      isSaved ? Icons.bookmark : Icons.bookmark_border,
                    ),
            ),
          ],
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              PhiWarningBanner(message: job.disclaimer),
              const SizedBox(height: 16),
              Text(
                job.serviceTypeLabel,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              if (job.payRateDisplay != null) ...[
                const SizedBox(height: 8),
                Text('Pay: ${job.payRateDisplay}'),
              ],
              if (job.publicDescription != null) ...[
                const SizedBox(height: 16),
                Text(job.publicDescription!),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _messageController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Application message (optional)',
                ),
              ),
              const SizedBox(height: 16),
              GlossyButton(
                label: _applying ? 'Submitting…' : 'Apply',
                onPressed: _applying ? null : _apply,
              ),
            ],
          ),
        );
      },
    );
  }
}
