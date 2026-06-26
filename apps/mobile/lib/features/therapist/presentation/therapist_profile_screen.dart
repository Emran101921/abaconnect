import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/router/app_router.dart';
import '../../clinical/data/clinical_charts_repository.dart';
import '../../clinical/data/clinical_repository.dart';
import '../data/therapist_repository.dart';
import '../../../shared/layout/dashboard_card.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_status_badge.dart';
import '../../../shared/widgets/app_trust_notice.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../../documents/presentation/documents_screen.dart';
import '../widgets/therapist_employment_documents_section.dart';

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
    clinicalChartsProvider(ClinicalChartsAudience.therapist);

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
      bottomNavigationBar: const RoleBottomNav(current: CoreNavTab.profile),
      body: profile.when(
        data: (p) {
          _initFromProfile(p);

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(therapistProfileProvider);
              ref.invalidate(therapistCaseloadChartsProvider);
              ref.invalidate(therapistBadgesProvider);
              ref.invalidate(documentsProvider);
            },
            child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DashboardCard(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      child: Text(
                        p.displayName.isNotEmpty ? p.displayName[0] : '?',
                        style: TextStyle(
                          fontSize: 32,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      p.displayName,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(
                      '${p.rating.toStringAsFixed(1)}★ · ${p.ratingCount} reviews',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 8),
                    if (p.isVerified)
                      AppStatusBadge.fromKind(
                        AppStatusKind.approved,
                        label: 'Verified provider',
                      )
                    else
                      AppStatusBadge.fromKind(
                        AppStatusKind.pending,
                        label: 'Verification pending',
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const AppTrustNotice.protectedInfo(dense: true),
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
              const SizedBox(height: 16),
              DashboardCard(
                title: 'Medical charts',
                onTap: () => context.push(AppRoutes.therapistCharts),
                trailing: const Icon(Icons.chevron_right),
                child: Text(
                  caseload.maybeWhen(
                    data: (charts) => charts.isEmpty
                        ? 'Each child on your caseload gets a separate chart.'
                        : '${charts.length} child chart${charts.length == 1 ? '' : 's'} on your caseload',
                    orElse: () =>
                        'Each child on your caseload gets a separate chart.',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DashboardCard(
                title: 'Credentials',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const TherapistEmploymentDocumentsSection(),
              const SizedBox(height: 16),
              DashboardCard(
                title: 'Bio',
                child: TextField(
                  controller: _bioController,
                  decoration: const InputDecoration(
                    labelText: 'Tell families about your practice',
                    border: InputBorder.none,
                  ),
                  maxLines: 3,
                ),
              ),
              const SizedBox(height: 24),
              GlossyButton(
                title: 'Save Profile',
                variant: GlossyButtonVariant.greenTeal,
                loading: _saving,
                onPressed: _save,
              ),
              const SizedBox(height: 16),
              GlossyButton.logOut(
                onPressed: () async {
                  await ref.read(authStateProvider.notifier).logout();
                  if (context.mounted) context.go(AppRoutes.login);
                },
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
