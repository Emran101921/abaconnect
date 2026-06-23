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
  JobOpportunityModel? _job;
  final _messageController = TextEditingController();
  bool _loading = true;
  bool _applying = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await ref
          .read(jobOpportunitiesRepositoryProvider)
          .browseJobOpportunities();
      JobOpportunityModel? match;
      for (final item in items) {
        if (item.id == widget.jobOpportunityId) {
          match = item;
          break;
        }
      }
      setState(() {
        _job = match;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AppScaffold(
        title: 'Job opportunity',
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final job = _job;
    if (job == null) {
      return const AppScaffold(
        title: 'Job opportunity',
        body: Center(child: Text('Opportunity not found')),
      );
    }

    return AppScaffold(
      title: job.title,
      subtitle: job.agencyName ?? job.locationAreaLabel,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PhiWarningBanner(message: job.disclaimer),
          const SizedBox(height: 16),
          Text(job.serviceTypeLabel, style: Theme.of(context).textTheme.titleSmall),
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
  }
}
