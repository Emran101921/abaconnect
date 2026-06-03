import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../data/parent_booking_repository.dart';

final parentProfileProvider = FutureProvider<ParentProfileModel>((ref) {
  return ref.watch(parentBookingRepositoryProvider).fetchParentProfile();
});

class ParentProfileScreen extends ConsumerStatefulWidget {
  const ParentProfileScreen({super.key});

  @override
  ConsumerState<ParentProfileScreen> createState() => _ParentProfileScreenState();
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
      await ref.read(parentBookingRepositoryProvider).updateParentProfile(
            addressLine1: _address.text.trim().isEmpty ? null : _address.text.trim(),
            city: _city.text.trim().isEmpty ? null : _city.text.trim(),
            state: _state.text.trim().isEmpty ? null : _state.text.trim(),
            zipCode: _zip.text.trim().isEmpty ? null : _zip.text.trim(),
            emergencyContactName:
                _emergencyName.text.trim().isEmpty ? null : _emergencyName.text.trim(),
            emergencyContactPhone:
                _emergencyPhone.text.trim().isEmpty ? null : _emergencyPhone.text.trim(),
            insuranceProvider: _insuranceProvider.text.trim().isEmpty
                ? null
                : _insuranceProvider.text.trim(),
            insuranceMemberId: _insuranceMemberId.text.trim().isEmpty
                ? null
                : _insuranceMemberId.text.trim(),
            insuranceGroupNumber:
                _insuranceGroup.text.trim().isEmpty ? null : _insuranceGroup.text.trim(),
          );
      ref.invalidate(parentProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(parentProfileProvider);

    return AppScaffold(
      title: 'My Profile',
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (p) {
          _fill(p);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ListTile(
                title: Text(p.fullName),
                subtitle: Text(p.email),
                leading: const CircleAvatar(child: Icon(Icons.person)),
              ),
              const SizedBox(height: 16),
              Text('Address', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
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
                      decoration: const InputDecoration(labelText: 'City'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 80,
                    child: TextField(
                      controller: _state,
                      decoration: const InputDecoration(labelText: 'State'),
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
              const SizedBox(height: 16),
              Text('Emergency contact', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              TextField(
                controller: _emergencyName,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: _emergencyPhone,
                decoration: const InputDecoration(labelText: 'Phone'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              Text('Insurance', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              TextField(
                controller: _insuranceProvider,
                decoration: const InputDecoration(labelText: 'Provider'),
              ),
              TextField(
                controller: _insuranceMemberId,
                decoration: const InputDecoration(labelText: 'Member ID'),
              ),
              TextField(
                controller: _insuranceGroup,
                decoration: const InputDecoration(labelText: 'Group number'),
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
                    : const Text('Save profile'),
              ),
            ],
          );
        },
      ),
    );
  }
}
