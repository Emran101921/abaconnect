import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/app_providers.dart';
import '../../clinical/data/clinical_repository.dart';
import '../data/therapist_repository.dart';
import '../../../shared/widgets/app_scaffold.dart';

final therapistBadgesProvider = FutureProvider<List<TherapistBadgeModel>>((
  ref,
) {
  return ref.watch(clinicalRepositoryProvider).fetchBadges();
});

final therapistProfileProvider = FutureProvider<TherapistProfileModel>((
  ref,
) async {
  return ref.watch(therapistRepositoryProvider).fetchProfile();
});

final therapistCaseloadChartsProvider =
    FutureProvider<List<TherapistCaseloadChartModel>>((ref) async {
  return ref.watch(therapistRepositoryProvider).fetchCaseloadCharts();
});

class TherapistProfileScreen extends ConsumerStatefulWidget {
  const TherapistProfileScreen({super.key});

  @override
  ConsumerState<TherapistProfileScreen> createState() =>
      _TherapistProfileScreenState();
}

class _TherapistProfileScreenState
    extends ConsumerState<TherapistProfileScreen> {
  final _bioController = TextEditingController();
  final _npiController = TextEditingController();
  final _licenseController = TextEditingController();
  final _stateController = TextEditingController();
  bool _saving = false;
  bool _initialized = false;

  @override
  void dispose() {
    _bioController.dispose();
    _npiController.dispose();
    _licenseController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  void _initFromProfile(TherapistProfileModel p) {
    if (_initialized) return;
    _bioController.text = p.bio ?? '';
    _npiController.text = p.npi ?? '';
    _licenseController.text = p.licenseNumber ?? '';
    _stateController.text = p.licenseState ?? '';
    _initialized = true;
  }

  Future<void> _save() async {
    final npi = _npiController.text.trim();
    final license = _licenseController.text.trim();
    if (npi.isEmpty || license.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('NPI number and state license number are required'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(therapistRepositoryProvider).updateProfile(
            bio: _bioController.text.trim(),
            npi: npi,
            licenseNumber: license,
            licenseState: _stateController.text.trim(),
          );
      ref.invalidate(therapistProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile saved')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(therapistProfileProvider);
    final badges = ref.watch(therapistBadgesProvider);
    final caseload = ref.watch(therapistCaseloadChartsProvider);

    return AppScaffold(
      title: 'My Profile',
      body: profile.when(
        data: (p) {
          _initFromProfile(p);

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(therapistProfileProvider);
              ref.invalidate(therapistCaseloadChartsProvider);
              ref.invalidate(therapistBadgesProvider);
            },
            child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              CircleAvatar(
                radius: 48,
                child: Text(
                  p.displayName.isNotEmpty ? p.displayName[0] : '?',
                  style: const TextStyle(fontSize: 32),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  p.displayName,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              Center(
                child: Text(
                  '${p.rating.toStringAsFixed(1)}★ · ${p.ratingCount} reviews',
                ),
              ),
              if (p.isVerified)
                const Center(
                  child: Chip(
                    label: Text('Verified'),
                    avatar: Icon(Icons.verified, size: 18),
                  ),
                ),
              if (!p.hasRequiredCredentials) ...[
                const SizedBox(height: 16),
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'Add your NPI and state license number below. '
                      'Required for session notes and billing.',
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              badges.when(
                data: (list) => list.isEmpty
                    ? const SizedBox.shrink()
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: list
                            .map((b) => Chip(label: Text(b.label ?? b.type)))
                            .toList(),
                      ),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 24),
              Text(
                'Caseload · Medical charts',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Each child has a separate clinical chart on your caseload.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),
              caseload.when(
                data: (charts) {
                  if (charts.isEmpty) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'No children on your caseload yet.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (var i = 0; i < charts.length; i++) ...[
                        if (i > 0) const SizedBox(height: 12),
                        _MedicalChartCard(chart: charts[i]),
                      ],
                    ],
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('Could not load caseload: $e'),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Credentials',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _npiController,
                decoration: const InputDecoration(
                  labelText: 'NPI number *',
                  hintText: '10-digit National Provider Identifier',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _licenseController,
                decoration: const InputDecoration(
                  labelText: 'State license number *',
                  hintText: 'License / certification #',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _stateController,
                decoration: const InputDecoration(
                  labelText: 'License state',
                  hintText: 'e.g. NY',
                ),
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(2),
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z]')),
                ],
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _bioController,
                decoration: const InputDecoration(labelText: 'Bio'),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save Profile'),
              ),
            ],
          ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _MedicalChartCard extends StatelessWidget {
  const _MedicalChartCard({required this.chart});

  final TherapistCaseloadChartModel chart;

  String _formatGender(String? gender) {
    if (gender == null || gender.isEmpty) return '—';
    return gender
        .split('-')
        .map((part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}')
        .join('-');
  }

  String _therapyLabel(String type) {
    switch (type) {
      case 'ABA':
        return 'ABA';
      case 'SPEECH':
        return 'Speech';
      case 'OT':
        return 'OT';
      case 'PT':
        return 'PT';
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFmt = DateFormat.yMMMd();

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: theme.colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                Icon(
                  Icons.medical_information_outlined,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    chart.chartNumber,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                ...chart.therapyTypes.map(
                  (t) => Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Chip(
                      label: Text(_therapyLabel(t)),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  chart.displayName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                _ChartField(
                  label: 'Date of birth',
                  value: dateFmt.format(chart.dateOfBirth),
                ),
                _ChartField(
                  label: 'Sex',
                  value: _formatGender(chart.gender),
                ),
                if (chart.primaryLanguage != null)
                  _ChartField(
                    label: 'Language',
                    value: chart.primaryLanguage!,
                  ),
                _ChartField(
                  label: 'Parent / guardian',
                  value: chart.guardianName ?? chart.parentName,
                ),
                if (chart.pediatricianName != null)
                  _ChartField(
                    label: 'Pediatrician',
                    value: chart.pediatricianName!,
                  ),
                if (chart.insuranceType != null)
                  _ChartField(
                    label: 'Insurance',
                    value: chart.insuranceType!,
                  ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ChartStat(
                      icon: Icons.event_outlined,
                      label: 'Upcoming',
                      value: '${chart.upcomingAppointments}',
                    ),
                    _ChartStat(
                      icon: Icons.check_circle_outline,
                      label: 'Sessions',
                      value: '${chart.completedSessions}',
                    ),
                    _ChartStat(
                      icon: Icons.edit_note_outlined,
                      label: 'Notes due',
                      value: '${chart.pendingDocumentation}',
                      highlight: chart.pendingDocumentation > 0,
                    ),
                  ],
                ),
                if (chart.lastVisitAt != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Last visit ${dateFmt.format(chart.lastVisitAt!)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartField extends StatelessWidget {
  const _ChartField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _ChartStat extends StatelessWidget {
  const _ChartStat({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = highlight
        ? theme.colorScheme.errorContainer
        : theme.colorScheme.secondaryContainer;
    final fg = highlight
        ? theme.colorScheme.onErrorContainer
        : theme.colorScheme.onSecondaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(
            '$label $value',
            style: theme.textTheme.labelMedium?.copyWith(color: fg),
          ),
        ],
      ),
    );
  }
}
