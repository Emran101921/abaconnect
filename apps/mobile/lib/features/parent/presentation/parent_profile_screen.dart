import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/layout/dashboard_card.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_status_badge.dart';
import '../../../shared/widgets/app_trust_notice.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../data/parent_booking_repository.dart';
import 'parent_dashboard_providers.dart';

final parentProfileProvider = FutureProvider<ParentProfileModel>((ref) {
  return ref.watch(parentBookingRepositoryProvider).fetchParentProfile();
});

class ParentProfileScreen extends ConsumerStatefulWidget {
  const ParentProfileScreen({super.key});

  @override
  ConsumerState<ParentProfileScreen> createState() =>
      _ParentProfileScreenState();
}

class _ParentProfileScreenState extends ConsumerState<ParentProfileScreen> {
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _zip = TextEditingController();
  final _emergencyName = TextEditingController();
  final _emergencyPhone = TextEditingController();
  final _insuranceProvider = TextEditingController();
  final _insuranceMemberId = TextEditingController();
  final _insuranceGroup = TextEditingController();
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    _address.dispose();
    _city.dispose();
    _state.dispose();
    _zip.dispose();
    _emergencyName.dispose();
    _emergencyPhone.dispose();
    _insuranceProvider.dispose();
    _insuranceMemberId.dispose();
    _insuranceGroup.dispose();
    super.dispose();
  }

  void _fill(ParentProfileModel p) {
    if (_loaded) return;
    _address.text = p.addressLine1 ?? '';
    _city.text = p.city ?? '';
    _state.text = p.state ?? '';
    _zip.text = p.zipCode ?? '';
    _emergencyName.text = p.emergencyContactName ?? '';
    _emergencyPhone.text = p.emergencyContactPhone ?? '';
    _insuranceProvider.text = p.insuranceProvider ?? '';
    _insuranceMemberId.text = p.insuranceMemberId ?? '';
    _insuranceGroup.text = p.insuranceGroupNumber ?? '';
    _loaded = true;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(parentBookingRepositoryProvider)
          .updateParentProfile(
            addressLine1: _address.text.trim().isEmpty
                ? null
                : _address.text.trim(),
            city: _city.text.trim().isEmpty ? null : _city.text.trim(),
            state: _state.text.trim().isEmpty ? null : _state.text.trim(),
            zipCode: _zip.text.trim().isEmpty ? null : _zip.text.trim(),
            emergencyContactName: _emergencyName.text.trim().isEmpty
                ? null
                : _emergencyName.text.trim(),
            emergencyContactPhone: _emergencyPhone.text.trim().isEmpty
                ? null
                : _emergencyPhone.text.trim(),
            insuranceProvider: _insuranceProvider.text.trim().isEmpty
                ? null
                : _insuranceProvider.text.trim(),
            insuranceMemberId: _insuranceMemberId.text.trim().isEmpty
                ? null
                : _insuranceMemberId.text.trim(),
            insuranceGroupNumber: _insuranceGroup.text.trim().isEmpty
                ? null
                : _insuranceGroup.text.trim(),
          );
      ref.invalidate(parentProfileProvider);
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
    final profile = ref.watch(parentProfileProvider);
    final showPayments = ref
        .watch(parentShowsPaymentsProvider)
        .maybeWhen(data: (v) => v, orElse: () => true);

    return AppScaffold(
      title: 'My Profile',
      bottomNavigationBar: const RoleBottomNav(current: CoreNavTab.profile),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (p) {
          _fill(p);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DashboardCard(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      child: Icon(
                        Icons.person_outline,
                        size: 36,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.fullName,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            p.email,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          AppStatusBadge.fromKind(
                            AppStatusKind.active,
                            label: 'Family account',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const AppTrustNotice.dataProtected(dense: true),
              const SizedBox(height: 16),
              DashboardCard(
                title: 'Address',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _address,
                      decoration: const InputDecoration(labelText: 'Street'),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _city,
                            decoration:
                                const InputDecoration(labelText: 'City'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 80,
                          child: TextField(
                            controller: _state,
                            decoration:
                                const InputDecoration(labelText: 'State'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 100,
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
              const SizedBox(height: 16),
              DashboardCard(
                title: 'Emergency contact',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _emergencyName,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    TextField(
                      controller: _emergencyPhone,
                      decoration: const InputDecoration(labelText: 'Phone'),
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
              ),
              if (!showPayments) ...[
                const SizedBox(height: 16),
                DashboardCard(
                  title: 'Insurance',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _insuranceProvider,
                        decoration:
                            const InputDecoration(labelText: 'Provider'),
                      ),
                      TextField(
                        controller: _insuranceMemberId,
                        decoration:
                            const InputDecoration(labelText: 'Member ID'),
                      ),
                      TextField(
                        controller: _insuranceGroup,
                        decoration:
                            const InputDecoration(labelText: 'Group number'),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              GlossyButton(
                title: 'Save profile',
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
          );
        },
      ),
    );
  }
}
