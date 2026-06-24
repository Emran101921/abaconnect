import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/glossy_button.dart';
import 'agency_providers.dart';

class AgencyAddStaffScreen extends ConsumerStatefulWidget {
  const AgencyAddStaffScreen({super.key});

  @override
  ConsumerState<AgencyAddStaffScreen> createState() =>
      _AgencyAddStaffScreenState();
}

class _AgencyAddStaffScreenState extends ConsumerState<AgencyAddStaffScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _licenseController = TextEditingController();
  final _licenseStateController = TextEditingController();
  final _npiController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _licenseController.dispose();
    _licenseStateController.dispose();
    _npiController.dispose();
    super.dispose();
  }

  Future<void> _createStaff() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.length < 8 ||
        _firstNameController.text.trim().isEmpty ||
        _lastNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Email, password (8+ chars), first name, and last name are required',
          ),
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await ref.read(agencyRepositoryProvider).createAgencyStaff(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
            phone: _phoneController.text.trim().isEmpty
                ? null
                : _phoneController.text.trim(),
            licenseNumber: _licenseController.text.trim().isEmpty
                ? null
                : _licenseController.text.trim(),
            licenseState: _licenseStateController.text.trim().isEmpty
                ? null
                : _licenseStateController.text.trim(),
            npi: _npiController.text.trim().isEmpty
                ? null
                : _npiController.text.trim(),
          );
      ref.invalidate(agencyTherapistsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Staff member created')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create staff: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Add staff member',
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(
            'Create a therapist account under your agency. They will complete '
            'provider onboarding and required documents after signing in.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _firstNameController,
            decoration: const InputDecoration(labelText: 'First name'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _lastNameController,
            decoration: const InputDecoration(labelText: 'Last name'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: 'Email'),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _passwordController,
            decoration: const InputDecoration(labelText: 'Temporary password'),
            obscureText: true,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _phoneController,
            decoration: const InputDecoration(labelText: 'Phone (optional)'),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'License information',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _licenseController,
            decoration: const InputDecoration(labelText: 'License number'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _licenseStateController,
            decoration: const InputDecoration(labelText: 'License state'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _npiController,
            decoration: const InputDecoration(labelText: 'NPI (optional)'),
          ),
          const SizedBox(height: AppSpacing.xl),
          GlossyButton(
            title: 'Create staff account',
            loading: _loading,
            onPressed: _createStaff,
          ),
        ],
      ),
    );
  }
}
