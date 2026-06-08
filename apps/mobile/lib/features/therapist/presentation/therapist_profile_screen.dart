import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

    return AppScaffold(
      title: 'My Profile',
      body: profile.when(
        data: (p) {
          _initFromProfile(p);

          return ListView(
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
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
