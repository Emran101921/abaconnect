import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/providers/consent_gate_provider.dart';
import '../../../core/router/onboarding_navigation.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/layout/auth_shell.dart';
import '../../../shared/models/user_role.dart';
import '../../../shared/widgets/app_select.dart';
import '../../../shared/widgets/app_trust_notice.dart';
import '../../../shared/widgets/glossy_button.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _agencyNameController = TextEditingController();
  final _agencyPhoneController = TextEditingController();
  final _agencyStateController = TextEditingController();
  final _agencyZipController = TextEditingController();
  UserRole _role = UserRole.parent;
  bool _loading = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _agencyNameController.dispose();
    _agencyPhoneController.dispose();
    _agencyStateController.dispose();
    _agencyZipController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_role == UserRole.agency &&
        _agencyNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agency name is required')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await ref
          .read(authStateProvider.notifier)
          .register(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
            role: _role,
            agencyName: _role == UserRole.agency
                ? _agencyNameController.text.trim()
                : null,
            agencyPhone: _role == UserRole.agency
                ? _agencyPhoneController.text.trim()
                : null,
            agencyState: _role == UserRole.agency
                ? _agencyStateController.text.trim()
                : null,
            agencyZipCode: _role == UserRole.agency
                ? _agencyZipController.text.trim()
                : null,
          );
      if (!mounted) return;
      final session = ref.read(authStateProvider).value;
      if (session != null) {
        final destination =
            resolveOnboardingRoute(
              role: session.user.role,
              hipaaConsentGranted: ref.read(hipaaConsentGrantedProvider),
              mfaEnabled: ref.read(mfaEnabledProvider),
              agencyOnboardingComplete:
                  ref.read(agencyOnboardingCompleteProvider),
            ) ??
            session.user.role.homeRoute;
        context.go(destination);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Registration failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: 'Start your family\'s\ncare journey',
      subtitle:
          'Create a secure account to manage screening, therapy, appointments, '
          'and progress — all in one place.',
      child: _buildForm(context),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => context.go('/login'),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('Back to sign in'),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Create account',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Family-friendly care coordination for Early Intervention',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _firstNameController,
          decoration: const InputDecoration(
            labelText: 'First name',
            prefixIcon: Icon(Icons.person_outline),
          ),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _lastNameController,
          decoration: const InputDecoration(
            labelText: 'Last name',
            prefixIcon: Icon(Icons.person_outline),
          ),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AppSpacing.md),
        AppSelectField<UserRole>(
          label: 'Account type',
          value: _role,
          prefixIcon: const Icon(Icons.badge_outlined),
          options: const [
            AppSelectOption(
              value: UserRole.parent,
              label: 'Parent / caregiver',
            ),
            AppSelectOption(
              value: UserRole.therapist,
              label: 'Therapist / provider',
            ),
            AppSelectOption(
              value: UserRole.agency,
              label: 'Agency administrator',
            ),
          ],
          onChanged: (v) => setState(() => _role = v ?? UserRole.parent),
        ),
        if (_role == UserRole.agency) ...[
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _agencyNameController,
            decoration: const InputDecoration(
              labelText: 'Agency name',
              prefixIcon: Icon(Icons.business_outlined),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _agencyPhoneController,
            decoration: const InputDecoration(
              labelText: 'Agency phone (optional)',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _agencyStateController,
            decoration: const InputDecoration(
              labelText: 'State (optional)',
              prefixIcon: Icon(Icons.map_outlined),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _agencyZipController,
            decoration: const InputDecoration(
              labelText: 'ZIP code (optional)',
              prefixIcon: Icon(Icons.pin_drop_outlined),
            ),
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _emailController,
          decoration: const InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.email_outlined),
          ),
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _passwordController,
          decoration: const InputDecoration(
            labelText: 'Password',
            prefixIcon: Icon(Icons.lock_outline),
          ),
          obscureText: true,
          onSubmitted: (_) => _loading ? null : _register(),
        ),
        const SizedBox(height: AppSpacing.md),
        const AppTrustNotice.dataProtected(dense: true),
        const SizedBox(height: AppSpacing.lg),
        GlossyButton(
          title: 'Create account',
          variant: GlossyButtonVariant.primary,
          loading: _loading,
          onPressed: _register,
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: () => context.go('/login'),
          child: const Text('Already have an account? Sign in'),
        ),
      ],
    );
  }
}
