import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/providers/consent_gate_provider.dart';
import '../../../core/router/onboarding_navigation.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/layout/auth_shell.dart';
import '../../../shared/layout/form_input.dart';
import '../../../shared/models/user_role.dart';
import '../../../shared/widgets/app_select.dart';
import '../../../shared/widgets/app_trust_notice.dart';
import '../../../shared/widgets/glossy_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginRoleOption {
  const _LoginRoleOption({
    required this.role,
    required this.label,
    required this.subtitle,
    required this.icon,
    this.demoEmail,
    this.demoPassword,
  });

  final UserRole role;
  final String label;
  final String subtitle;
  final IconData icon;
  final String? demoEmail;
  final String? demoPassword;
}

const _loginRoles = [
  _LoginRoleOption(
    role: UserRole.parent,
    label: 'Parent',
    subtitle: 'Family care dashboard',
    icon: Icons.family_restroom_outlined,
    demoEmail: 'parent1@demo.local',
    demoPassword: 'Parent1Demo!',
  ),
  _LoginRoleOption(
    role: UserRole.therapist,
    label: 'Therapist',
    subtitle: 'Clinical sessions & notes',
    icon: Icons.medical_services_outlined,
    demoEmail: 'therapist@demo.local',
    demoPassword: 'Therapist123!',
  ),
  _LoginRoleOption(
    role: UserRole.agency,
    label: 'Agency',
    subtitle: 'Roster & operations',
    icon: Icons.business_outlined,
    demoEmail: 'agency@demo.local',
    demoPassword: 'Agency123!',
  ),
  _LoginRoleOption(
    role: UserRole.serviceCoordinator,
    label: 'Service coordinator',
    subtitle: 'EI cases & follow-ups',
    icon: Icons.support_agent_outlined,
    demoEmail: 'sc@demo.local',
    demoPassword: 'SC123!',
  ),
  _LoginRoleOption(
    role: UserRole.admin,
    label: 'Admin',
    subtitle: 'Platform administration',
    icon: Icons.admin_panel_settings_outlined,
    demoEmail: 'admin@abaconnect.local',
    demoPassword: 'Admin123!',
  ),
];

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late UserRole _selectedRole;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _selectedRole = UserRole.parent;
    _applyRoleDefaults(_loginRoles.first);
  }

  void _applyRoleDefaults(_LoginRoleOption option) {
    if (kDebugMode && option.demoEmail != null && option.demoPassword != null) {
      _emailController.text = option.demoEmail!;
      _passwordController.text = option.demoPassword!;
    }
  }

  void _selectRole(_LoginRoleOption option) {
    setState(() {
      _selectedRole = option.role;
      _applyRoleDefaults(option);
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() => _loading = true);
    try {
      final result = await ref
          .read(authStateProvider.notifier)
          .login(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            role: _selectedRole,
          );
      if (!mounted) return;
      if (result.requiresMfa) {
        final code = await _promptMfaCode(newDevice: result.newDevice);
        if (code == null || !mounted) return;
        await ref
            .read(authStateProvider.notifier)
            .completeMfaLogin(
              mfaChallengeToken: result.mfaChallengeToken!,
              code: code,
            );
      }
      if (!mounted) return;
      final session = ref.read(authStateProvider).value;
      if (session != null) {
        final destination =
            resolveOnboardingRoute(
              role: session.user.role,
              hipaaConsentGranted: ref.read(hipaaConsentGrantedProvider),
              mfaEnabled: ref.read(mfaEnabledProvider),
            ) ??
            session.user.role.homeRoute;
        context.go(destination);
      }
    } catch (e) {
      if (mounted) {
        final message = _loginErrorMessage(e);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _loginErrorMessage(Object error) {
    if (error is DioException &&
        (error.type == DioExceptionType.connectionError ||
            error.type == DioExceptionType.connectionTimeout)) {
      return 'Cannot reach API at ${ApiConstants.baseUrl}. '
          'Start Docker + API on your Mac (cd api && npm run start:dev).';
    }
    return 'Login failed: $error';
  }

  Future<String?> _promptMfaCode({bool newDevice = false}) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(newDevice ? 'Verify new device' : 'Authenticator code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (newDevice) ...[
              const Text(
                'We detected a sign-in from a new device. Enter your '
                'authenticator code to trust this device. Your device model, '
                'IP address, and approximate location will be recorded.',
              ),
              const SizedBox(height: 12),
            ],
            if (kDebugMode) ...[
              const Text(
                'Local dev: use MFA code 000000 when DEV_MFA_BYPASS_CODE is '
                'set in api/.env, or run: cd api && npm run demo:mfa-code',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: '6-digit code',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              maxLength: 6,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          GlossyButton(
            title: 'Verify',
            size: GlossyButtonSize.small,
            fullWidth: false,
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(child: _buildForm(context));
  }

  Widget _buildForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Sign in',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Access your secure care dashboard',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppSelectField<UserRole>(
          label: 'Account type',
          value: _selectedRole,
          prefixIcon: Icon(
            _loginRoles
                .firstWhere((r) => r.role == _selectedRole)
                .icon,
            color: Theme.of(context).colorScheme.primary,
          ),
          options: _loginRoles
              .map(
                (r) => AppSelectOption(
                  value: r.role,
                  label: r.label,
                  subtitle: r.subtitle,
                  leading: Icon(r.icon),
                ),
              )
              .toList(),
          onChanged: (role) {
            if (role == null) return;
            final option = _loginRoles.firstWhere((o) => o.role == role);
            _selectRole(option);
          },
        ),
        const SizedBox(height: AppSpacing.md),
        if (kDebugMode) ...[
          Text(
            'Dev: API at ${ApiConstants.apiHost}:3000',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        FormInput(
          label: 'Email',
          controller: _emailController,
          hint: 'you@example.com',
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          prefixIcon: const Icon(Icons.email_outlined),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AppSpacing.md),
        FormInput(
          label: 'Password',
          controller: _passwordController,
          obscureText: true,
          autofillHints: const [AutofillHints.password],
          prefixIcon: const Icon(Icons.lock_outline),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _signIn(),
        ),
        const SizedBox(height: AppSpacing.md),
        const AppTrustNotice(dense: true),
        const SizedBox(height: AppSpacing.lg),
        GlossyButton(
          title: 'Sign in',
          variant: GlossyButtonVariant.primary,
          loading: _loading,
          onPressed: _signIn,
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () => context.push('/register'),
              child: const Text('Create account'),
            ),
            Text('·', style: Theme.of(context).textTheme.bodySmall),
            TextButton(
              onPressed: () => context.push('/forgot-password'),
              child: const Text('Forgot password'),
            ),
          ],
        ),
      ],
    );
  }
}

