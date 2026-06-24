import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/layout/dashboard_card.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/app_trust_notice.dart';
import '../../../shared/models/child_medical_chart_model.dart';
import '../../../shared/widgets/child_medical_chart_card.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../../clinical/data/clinical_charts_repository.dart';
import '../../parent/data/parent_booking_repository.dart';
import '../../parent/presentation/child_profile_form.dart';
import '../data/agency_repository.dart';
import 'agency_onboarding_screen.dart';

final agencyManagedChildrenProvider =
    FutureProvider<List<ChildModel>>((ref) {
  return ref.watch(agencyRepositoryProvider).fetchAgencyManagedChildren();
});

Future<ChildModel?> showAgencyChildProfileSheet(
  BuildContext context, {
  ChildModel? existing,
}) {
  return showModalBottomSheet<ChildModel>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _AgencyChildProfileSheet(existing: existing),
  );
}

class _AgencyChildProfileSheet extends ConsumerStatefulWidget {
  const _AgencyChildProfileSheet({this.existing});

  final ChildModel? existing;

  bool get isEditing => existing != null;

  @override
  ConsumerState<_AgencyChildProfileSheet> createState() =>
      _AgencyChildProfileSheetState();
}

class _AgencyChildProfileSheetState extends ConsumerState<_AgencyChildProfileSheet> {
  late ChildProfileFormData _data;
  bool _saving = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _data = widget.existing != null
        ? ChildProfileFormData.fromChild(widget.existing!)
        : ChildProfileFormData();
    if (widget.existing != null) {
      _refreshChild();
    }
  }

  Future<void> _refreshChild() async {
    setState(() => _loading = true);
    try {
      final child = await ref
          .read(agencyRepositoryProvider)
          .fetchAgencyManagedChild(widget.existing!.id);
      if (mounted) {
        setState(() => _data = ChildProfileFormData.fromChild(child));
      }
    } catch (_) {
      // Keep chart-derived values if fetch fails.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_data.isValid) {
      AppSnackBar.showError(
        context,
        'Please complete all required fields before saving.',
      );
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(agencyRepositoryProvider);
    try {
      final ChildModel child;
      if (widget.isEditing) {
        child = await repo.updateAgencyCaseloadChild(
          childId: widget.existing!.id,
          firstName: _data.firstName.trim(),
          lastName: _data.lastName.trim(),
          dateOfBirth: _data.dateOfBirth,
          gender: _data.gender,
          primaryLanguage: _data.primaryLanguage,
          guardianName: _data.guardianName?.trim(),
          guardianPhone: _data.guardianPhone?.trim(),
          guardianEmail: _data.guardianEmail?.trim(),
          addressLine1: _data.addressLine1?.trim(),
          zipCode: _data.zipCode?.trim(),
          pediatricianName: _data.pediatricianName?.trim(),
          insuranceType: _data.insuranceType,
          hadEarlyIntervention: _data.hadEarlyIntervention,
        );
      } else {
        child = await repo.addAgencyCaseloadChild(
          firstName: _data.firstName.trim(),
          lastName: _data.lastName.trim(),
          dateOfBirth: _data.dateOfBirth,
          gender: _data.gender,
          primaryLanguage: _data.primaryLanguage,
          guardianName: _data.guardianName?.trim(),
          guardianPhone: _data.guardianPhone?.trim(),
          guardianEmail: _data.guardianEmail?.trim(),
          addressLine1: _data.addressLine1?.trim(),
          zipCode: _data.zipCode?.trim(),
          pediatricianName: _data.pediatricianName?.trim(),
          insuranceType: _data.insuranceType,
          hadEarlyIntervention: _data.hadEarlyIntervention,
        );
      }
      ref.invalidate(clinicalChartsProvider(ClinicalChartsAudience.agency));
      ref.invalidate(agencyManagedChildrenProvider);
      if (mounted) Navigator.pop(context, child);
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          widget.isEditing
              ? 'Could not update child: ${AppSnackBar.messageFromError(e)}'
              : 'Could not add child: ${AppSnackBar.messageFromError(e)}',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text(
                      widget.isEditing
                          ? 'Edit child profile'
                          : 'Add child to caseload',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: AppTrustNotice.protectedInfo(dense: true),
              ),
              const SizedBox(height: 8),
              if (_loading)
                const LinearProgressIndicator()
              else
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ChildProfileForm(
                      data: _data,
                      onChanged: () => setState(() {}),
                    ),
                  ),
                ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: GlossyButton(
                    title: widget.isEditing ? 'Save changes' : 'Add to caseload',
                    variant: GlossyButtonVariant.greenTeal,
                    loading: _saving,
                    onPressed: _save,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class AgencyProfileScreen extends ConsumerStatefulWidget {
  const AgencyProfileScreen({super.key});

  @override
  ConsumerState<AgencyProfileScreen> createState() =>
      _AgencyProfileScreenState();
}

class _AgencyProfileScreenState extends ConsumerState<AgencyProfileScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _zip = TextEditingController();
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _city.dispose();
    _state.dispose();
    _zip.dispose();
    super.dispose();
  }

  void _fill(AgencyProfileModel profile) {
    if (_loaded) return;
    _name.text = profile.name;
    _phone.text = profile.phone ?? '';
    _email.text = profile.email ?? '';
    _address.text = profile.addressLine1 ?? '';
    _city.text = profile.city ?? '';
    _state.text = profile.state ?? '';
    _zip.text = profile.zipCode ?? '';
    _loaded = true;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(agencyRepositoryProvider).updateAgencyProfile(
            name: _name.text.trim(),
            phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
            email: _email.text.trim().isEmpty ? null : _email.text.trim(),
            addressLine1:
                _address.text.trim().isEmpty ? null : _address.text.trim(),
            city: _city.text.trim().isEmpty ? null : _city.text.trim(),
            state: _state.text.trim().isEmpty ? null : _state.text.trim(),
            zipCode: _zip.text.trim().isEmpty ? null : _zip.text.trim(),
          );
      ref.invalidate(agencyProfileProvider);
      if (mounted) {
        AppSnackBar.showSuccess(context, 'Agency profile updated.');
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, AppSnackBar.messageFromError(e));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addChild() async {
    final child = await showAgencyChildProfileSheet(context);
    if (child == null || !mounted) return;
    ref.invalidate(agencyManagedChildrenProvider);
    AppSnackBar.showSuccess(context, '${child.displayName} added to caseload.');
    context.push(AppRoutes.agencyChildChart(child.id));
  }

  Future<void> _editChild(ChildModel child) async {
    final updated = await showAgencyChildProfileSheet(
      context,
      existing: child,
    );
    if (updated == null || !mounted) return;
    AppSnackBar.showSuccess(context, '${updated.displayName} updated.');
    ref.invalidate(clinicalChartsProvider(ClinicalChartsAudience.agency));
    ref.invalidate(agencyManagedChildrenProvider);
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(agencyProfileProvider);

    return AppScaffold(
      title: 'Agency profile',
      subtitle: 'Organization & caseload',
      bottomNavigationBar: const RoleBottomNav(current: CoreNavTab.profile),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(AppSnackBar.messageFromError(e))),
        data: (profile) {
          _fill(profile);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            children: [
              const AppTrustNotice.dataProtected(dense: true),
              const SizedBox(height: AppSpacing.md),
              DashboardCard(
                title: 'Organization',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _name,
                      decoration: const InputDecoration(labelText: 'Agency name'),
                    ),
                    TextField(
                      controller: _phone,
                      decoration: const InputDecoration(labelText: 'Phone'),
                      keyboardType: TextInputType.phone,
                    ),
                    TextField(
                      controller: _email,
                      decoration: const InputDecoration(labelText: 'Email'),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    TextField(
                      controller: _address,
                      decoration: const InputDecoration(labelText: 'Street'),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _city,
                            decoration: const InputDecoration(labelText: 'City'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 72,
                          child: TextField(
                            controller: _state,
                            decoration: const InputDecoration(labelText: 'State'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 96,
                          child: TextField(
                            controller: _zip,
                            decoration: const InputDecoration(labelText: 'ZIP'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              GlossyButton(
                title: 'Save profile',
                variant: GlossyButtonVariant.greenTeal,
                loading: _saving,
                onPressed: _save,
              ),
              const SizedBox(height: AppSpacing.lg),
              AgencyCaseloadSection(
                onAddChild: _addChild,
                onEditChild: _editChild,
              ),
              const SizedBox(height: AppSpacing.lg),
              GlossyButton.logOut(
                onPressed: () async {
                  await ref.read(authStateProvider.notifier).logout();
                  if (context.mounted) context.go(AppRoutes.login);
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Shared caseload list for agency profile and children routes.
class AgencyCaseloadSection extends ConsumerWidget {
  const AgencyCaseloadSection({
    super.key,
    required this.onAddChild,
    this.onEditChild,
  });

  final VoidCallback onAddChild;
  final Future<void> Function(ChildModel child)? onEditChild;

  ChildModel _childFromChart(
    ChildMedicalChartModel chart,
    Map<String, ChildModel> managedById,
  ) {
    final managed = managedById[chart.childId];
    if (managed != null) return managed;
    return ChildModel(
      id: chart.childId,
      firstName: chart.firstName,
      lastName: chart.lastName,
      dateOfBirth: chart.dateOfBirth,
      gender: chart.gender,
      primaryLanguage: chart.primaryLanguage,
      guardianName: chart.guardianName,
      pediatricianName: chart.pediatricianName,
      insuranceType: chart.insuranceType,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final charts = ref.watch(clinicalChartsProvider(ClinicalChartsAudience.agency));
    final managed = ref.watch(agencyManagedChildrenProvider);
    final managedById = managed.maybeWhen(
      data: (children) => {for (final child in children) child.id: child},
      orElse: () => const <String, ChildModel>{},
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Children & charts',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: onAddChild,
              icon: const Icon(Icons.person_add_outlined, size: 18),
              label: const Text('Add child'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        charts.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text(AppSnackBar.messageFromError(e)),
          data: (list) {
            if (list.isEmpty) {
              return DashboardCard(
                title: 'No children yet',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Add a child to start a clinical chart with documentation tabs.',
                    ),
                    const SizedBox(height: 12),
                    GlossyButton(
                      title: 'Add first child',
                      variant: GlossyButtonVariant.bluePurple,
                      onPressed: onAddChild,
                    ),
                  ],
                ),
              );
            }
            return Column(
              children: [
                for (final chart in list) ...[
                  ChildMedicalChartCard(
                    chart: chart,
                    onTap: () => context.push(AppRoutes.agencyChildChart(chart.childId)),
                    trailing: managedById.containsKey(chart.childId) &&
                            onEditChild != null
                        ? IconButton(
                            tooltip: 'Edit child profile',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => onEditChild!(
                              _childFromChart(chart, managedById),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class AgencyChildrenScreen extends ConsumerWidget {
  const AgencyChildrenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> addChild() async {
      final child = await showAgencyChildProfileSheet(context);
      if (child == null || !context.mounted) return;
      AppSnackBar.showSuccess(context, '${child.displayName} added to caseload.');
      context.push(AppRoutes.agencyChildChart(child.id));
    }

    Future<void> editChild(ChildModel child) async {
      final updated = await showAgencyChildProfileSheet(
        context,
        existing: child,
      );
      if (updated == null || !context.mounted) return;
      AppSnackBar.showSuccess(context, '${updated.displayName} updated.');
      ref.invalidate(clinicalChartsProvider(ClinicalChartsAudience.agency));
      ref.invalidate(agencyManagedChildrenProvider);
    }

    return AppScaffold(
      title: 'Agency caseload',
      subtitle: 'Children & clinical charts',
      bottomNavigationBar: const RoleBottomNav(current: CoreNavTab.profile),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(clinicalChartsProvider(ClinicalChartsAudience.agency));
          ref.invalidate(agencyManagedChildrenProvider);
          await ref.read(
            clinicalChartsProvider(ClinicalChartsAudience.agency).future,
          );
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
          children: [
            const AppTrustNotice.protectedInfo(dense: true),
            const SizedBox(height: AppSpacing.md),
            AgencyCaseloadSection(
              onAddChild: addChild,
              onEditChild: editChild,
            ),
          ],
        ),
      ),
    );
  }
}
