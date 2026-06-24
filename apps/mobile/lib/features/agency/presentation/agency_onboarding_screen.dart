import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/providers/consent_gate_provider.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/document_upload.dart';
import '../../../shared/layout/onboarding_wizard_shell.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../data/agency_repository.dart';

final agencyProfileProvider = FutureProvider<AgencyProfileModel>((ref) {
  return ref.watch(agencyRepositoryProvider).fetchAgencyProfile();
});

final agencyOnboardingStatusProvider =
    FutureProvider<AgencyOnboardingStatusModel>((ref) {
      return ref.watch(agencyRepositoryProvider).fetchOnboardingStatus();
    });

class AgencyOnboardingScreen extends ConsumerStatefulWidget {
  const AgencyOnboardingScreen({super.key});

  @override
  ConsumerState<AgencyOnboardingScreen> createState() =>
      _AgencyOnboardingScreenState();
}

class _AgencyOnboardingScreenState extends ConsumerState<AgencyOnboardingScreen> {
  final _nameController = TextEditingController();
  final _einController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _zipController = TextEditingController();
  int _step = 0;
  bool _loading = false;
  bool _initialized = false;

  @override
  void dispose() {
    _nameController.dispose();
    _einController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipController.dispose();
    super.dispose();
  }

  void _initFromProfile(AgencyProfileModel profile) {
    if (_initialized) return;
    _nameController.text = profile.name;
    _einController.text = profile.ein ?? '';
    _phoneController.text = profile.phone ?? '';
    _addressController.text = profile.addressLine1 ?? '';
    _cityController.text = profile.city ?? '';
    _stateController.text = profile.state ?? '';
    _zipController.text = profile.zipCode ?? '';
    _initialized = true;
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agency name is required')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(agencyRepositoryProvider).updateAgencyProfile(
            name: _nameController.text.trim(),
            ein: _einController.text.trim().isEmpty
                ? null
                : _einController.text.trim(),
            phone: _phoneController.text.trim().isEmpty
                ? null
                : _phoneController.text.trim(),
            addressLine1: _addressController.text.trim().isEmpty
                ? null
                : _addressController.text.trim(),
            city: _cityController.text.trim().isEmpty
                ? null
                : _cityController.text.trim(),
            state: _stateController.text.trim().isEmpty
                ? null
                : _stateController.text.trim(),
            zipCode: _zipController.text.trim().isEmpty
                ? null
                : _zipController.text.trim(),
          );
      ref.invalidate(agencyProfileProvider);
      ref.invalidate(agencyOnboardingStatusProvider);
      if (mounted) setState(() => _step = 1);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _uploadDocument(String type, String label) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: documentUploadExtensions,
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read file bytes')),
        );
      }
      return;
    }
    final mimeType = file.extension != null
        ? mimeFromExtension(file.extension!)
        : 'application/octet-stream';
    final validationError = validateDocumentUpload(
      extension: file.extension,
      mimeType: mimeType,
    );
    if (validationError != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(validationError)),
        );
      }
      return;
    }

    setState(() => _loading = true);
    try {
      await ref.read(agencyRepositoryProvider).uploadAgencyDocument(
            type: type,
            title: label,
            fileName: file.name,
            bytes: bytes,
            mimeType: mimeType,
          );
      ref.invalidate(agencyProfileProvider);
      ref.invalidate(agencyOnboardingStatusProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label uploaded')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitOnboarding() async {
    setState(() => _loading = true);
    try {
      await ref.read(agencyRepositoryProvider).completeAgencyOnboarding();
      ref.invalidate(agencyOnboardingStatusProvider);
      ref.read(agencyOnboardingCompleteProvider.notifier).state = true;
      if (mounted) context.go(AppRoutes.agencyHome);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not complete onboarding: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(agencyProfileProvider);
    final statusAsync = ref.watch(agencyOnboardingStatusProvider);

    return AppScaffold(
      title: 'Agency onboarding',
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (profile) {
          _initFromProfile(profile);
          return statusAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (status) {
              if (status.onboardingComplete) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_outline, size: 48),
                      const SizedBox(height: 12),
                      const Text('Agency onboarding is complete.'),
                      const SizedBox(height: 16),
                      GlossyButton(
                        title: 'Go to dashboard',
                        onPressed: () => context.go(AppRoutes.agencyHome),
                      ),
                    ],
                  ),
                );
              }

              return ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  OnboardingWizardShell(
                    title: 'Agency onboarding',
                    subtitle: 'Complete your agency profile, documents, and review.',
                    currentStep: _step + 1,
                    totalSteps: 3,
                    stepLabels: const [
                      'Profile',
                      'Documents',
                      'Review',
                    ],
                    child: const SizedBox.shrink(),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Stepper(
                    currentStep: _step,
                    onStepContinue: _loading
                        ? null
                        : () {
                            if (_step == 0) {
                              _saveProfile();
                            } else if (_step == 1 &&
                                status.documentsComplete) {
                              setState(() => _step = 2);
                            } else if (_step == 2 && status.canComplete) {
                              _submitOnboarding();
                            }
                          },
                    onStepCancel: _step > 0
                        ? () => setState(() => _step -= 1)
                        : null,
                    controlsBuilder: (context, details) {
                      return Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.md),
                        child: Row(
                          children: [
                            GlossyButton(
                              title: _step == 2 ? 'Submit' : 'Continue',
                              loading: _loading,
                              size: GlossyButtonSize.small,
                              fullWidth: false,
                              onPressed: details.onStepContinue,
                            ),
                            if (details.onStepCancel != null) ...[
                              const SizedBox(width: AppSpacing.sm),
                              TextButton(
                                onPressed: details.onStepCancel,
                                child: const Text('Back'),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                    steps: [
                      Step(
                        title: const Text('Agency profile'),
                        isActive: _step >= 0,
                        state: status.profileComplete
                            ? StepState.complete
                            : _step == 0
                            ? StepState.editing
                            : StepState.indexed,
                        content: Column(
                          children: [
                            TextField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Agency name',
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            TextField(
                              controller: _einController,
                              decoration: const InputDecoration(
                                labelText: 'EIN (optional)',
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            TextField(
                              controller: _phoneController,
                              decoration: const InputDecoration(
                                labelText: 'Phone',
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            TextField(
                              controller: _addressController,
                              decoration: const InputDecoration(
                                labelText: 'Address',
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            TextField(
                              controller: _cityController,
                              decoration: const InputDecoration(
                                labelText: 'City',
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            TextField(
                              controller: _stateController,
                              decoration: const InputDecoration(
                                labelText: 'State',
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            TextField(
                              controller: _zipController,
                              decoration: const InputDecoration(
                                labelText: 'ZIP code',
                              ),
                            ),
                          ],
                        ),
                      ),
                      Step(
                        title: const Text('Required documents'),
                        isActive: _step >= 1,
                        state: status.documentsComplete
                            ? StepState.complete
                            : _step == 1
                            ? StepState.editing
                            : StepState.indexed,
                        content: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Upload your Business Associate Agreement (BAA) '
                              'and business license to continue.',
                            ),
                            const SizedBox(height: AppSpacing.md),
                            _DocumentUploadTile(
                              label: 'BAA',
                              uploaded: status.uploadedDocumentTypes
                                  .contains('BAA'),
                              onUpload: () =>
                                  _uploadDocument('BAA', 'Business Associate Agreement'),
                            ),
                            _DocumentUploadTile(
                              label: 'Business license',
                              uploaded: status.uploadedDocumentTypes
                                  .contains('BUSINESS_LICENSE'),
                              onUpload: () => _uploadDocument(
                                'BUSINESS_LICENSE',
                                'Business license',
                              ),
                            ),
                          ],
                        ),
                      ),
                      Step(
                        title: const Text('Review & submit'),
                        isActive: _step >= 2,
                        state: _step == 2
                            ? StepState.editing
                            : StepState.indexed,
                        content: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Agency: ${profile.name}'),
                            const SizedBox(height: 8),
                            Text(
                              status.canComplete
                                  ? 'All requirements are met. Submit to access your agency dashboard.'
                                  : 'Complete your profile and upload required documents before submitting.',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _DocumentUploadTile extends StatelessWidget {
  const _DocumentUploadTile({
    required this.label,
    required this.uploaded,
    required this.onUpload,
  });

  final String label;
  final bool uploaded;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(
          uploaded ? Icons.check_circle : Icons.upload_file_outlined,
          color: uploaded ? Colors.green : null,
        ),
        title: Text(label),
        subtitle: Text(uploaded ? 'Uploaded' : 'Required'),
        trailing: uploaded
            ? null
            : GlossyButton(
                title: 'Upload',
                size: GlossyButtonSize.small,
                fullWidth: false,
                onPressed: onUpload,
              ),
      ),
    );
  }
}
