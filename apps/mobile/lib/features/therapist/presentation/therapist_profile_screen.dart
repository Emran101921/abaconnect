import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../data/therapist_repository.dart';
import '../../../shared/widgets/app_scaffold.dart';

final therapistProfileProvider =
    FutureProvider<TherapistProfileModel>((ref) async {
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
  final _licenseController = TextEditingController();
  final _stateController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _bioController.dispose();
    _licenseController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(therapistRepositoryProvider).updateProfile(
            bio: _bioController.text.trim(),
            licenseNumber: _licenseController.text.trim(),
            licenseState: _stateController.text.trim(),
          );
      ref.invalidate(therapistProfileProvider);
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
    final profile = ref.watch(therapistProfileProvider);

    return AppScaffold(
      title: 'My Profile',
      body: profile.when(
        data: (p) {
          if (_bioController.text.isEmpty && (p.bio ?? '').isNotEmpty) {
            _bioController.text = p.bio!;
          }
          if (_licenseController.text.isEmpty &&
              (p.licenseNumber ?? '').isNotEmpty) {
            _licenseController.text = p.licenseNumber!;
          }
          if (_stateController.text.isEmpty &&
              (p.licenseState ?? '').isNotEmpty) {
            _stateController.text = p.licenseState!;
          }

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
              const SizedBox(height: 24),
              TextField(
                controller: _bioController,
                decoration: const InputDecoration(labelText: 'Bio'),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _licenseController,
                decoration: const InputDecoration(labelText: 'License Number'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _stateController,
                decoration: const InputDecoration(labelText: 'License State'),
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
