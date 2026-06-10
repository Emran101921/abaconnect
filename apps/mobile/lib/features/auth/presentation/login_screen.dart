import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/providers/consent_gate_provider.dart';
import '../../../core/router/onboarding_navigation.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/models/user_role.dart';
import '../../../shared/widgets/app_brand_logo.dart';
import '../../../shared/widgets/app_healthcare_illustration.dart';
import '../../../shared/widgets/app_theme_toggle.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController(
    text: kDebugMode ? 'parent@demo.local' : '',
  );
  final _passwordController = TextEditingController(
    text: kDebugMode ? 'Parent123!' : '',
  );
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn({UserRole? demoRole}) async {
    setState(() => _loading = true);
    try {
      final result = await ref
          .read(authStateProvider.notifier)
          .login(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            role: demoRole ?? UserRole.parent,
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
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      body: wide ? _buildWideLayout(context) : _buildNarrowLayout(context),
    );
  }

  Widget _buildWideLayout(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: const BoxDecoration(gradient: AppColors.warmGradient),
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    AppBrandLogo(
                      size: AppBrandLogoSize.large,
                      lightOnDark: true,
                    ),
                    Spacer(),
                    AppThemeToggle(compact: true),
                  ],
                ),
                const Spacer(),
                const AppHealthcareIllustration(
                  type: AppIllustrationType.family,
                  size: 140,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Care coordination\nfor every family',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Screening, therapy matching, sessions, billing, and '
                  'clinical documentation — one secure, family-friendly platform.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.92),
                    height: 1.5,
                  ),
                ),
                const Spacer(),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: const [
                    _FeatureChip(label: 'Early Intervention'),
                    _FeatureChip(label: 'HIPAA-aware'),
                    _FeatureChip(label: 'Family-first'),
                  ],
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: _buildForm(context),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.lg),
            Row(children: const [Spacer(), AppThemeToggle(compact: true)]),
            const SizedBox(height: AppSpacing.md),
            const Center(child: AppBrandLogo(size: AppBrandLogoSize.large)),
            const SizedBox(height: AppSpacing.md),
            const Center(
              child: AppHealthcareIllustration(
                type: AppIllustrationType.family,
                size: 100,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            _buildForm(context),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Sign in',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Access your care dashboard',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        if (kDebugMode) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Dev: API at ${ApiConstants.apiHost}:3000',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _emailController,
          decoration: const InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.email_outlined),
          ),
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _passwordController,
          decoration: const InputDecoration(
            labelText: 'Password',
            prefixIcon: Icon(Icons.lock_outline),
          ),
          obscureText: true,
          autofillHints: const [AutofillHints.password],
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: _loading ? null : () => _signIn(),
          child: _loading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Sign in'),
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
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Quick demo access',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _DemoChip(
              label: 'Parent',
              loading: _loading,
              onTap: () {
                _emailController.text = 'parent@demo.local';
                _passwordController.text = 'Parent123!';
                _signIn(demoRole: UserRole.parent);
              },
            ),
            _DemoChip(
              label: 'Therapist',
              loading: _loading,
              onTap: () {
                _emailController.text = 'therapist@demo.local';
                _passwordController.text = 'Therapist123!';
                _signIn(demoRole: UserRole.therapist);
              },
            ),
            _DemoChip(
              label: 'Admin',
              loading: _loading,
              onTap: () {
                _emailController.text = 'admin@abaconnect.local';
                _passwordController.text = 'Admin123!';
                _signIn(demoRole: UserRole.admin);
              },
            ),
            _DemoChip(
              label: 'Agency',
              loading: _loading,
              onTap: () {
                _emailController.text = 'agency@demo.local';
                _passwordController.text = 'Agency123!';
                _signIn(demoRole: UserRole.agency);
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DemoChip extends StatelessWidget {
  const _DemoChip({
    required this.label,
    required this.loading,
    required this.onTap,
  });

  final String label;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(label: Text(label), onPressed: loading ? null : onTap);
  }
}
