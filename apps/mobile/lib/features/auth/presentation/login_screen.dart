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
import '../../../core/theme/app_glossy_gradients.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/models/user_role.dart';
import '../../../shared/widgets/app_brand_logo.dart';
import '../../../shared/widgets/app_healthcare_illustration.dart';
import '../../../shared/widgets/app_theme_toggle.dart';
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
    required this.gradient,
    this.demoEmail,
    this.demoPassword,
  });

  final UserRole role;
  final String label;
  final String subtitle;
  final IconData icon;
  final LinearGradient gradient;
  final String? demoEmail;
  final String? demoPassword;
}

const _loginRoles = [
  _LoginRoleOption(
    role: UserRole.parent,
    label: 'Parent',
    subtitle: 'Family care dashboard',
    icon: Icons.family_restroom_outlined,
    gradient: AppGlossyGradients.primary,
    demoEmail: 'parent1@demo.local',
    demoPassword: 'Parent1Demo!',
  ),
  _LoginRoleOption(
    role: UserRole.therapist,
    label: 'Therapist',
    subtitle: 'Clinical sessions & notes',
    icon: Icons.medical_services_outlined,
    gradient: AppGlossyGradients.secondary,
    demoEmail: 'therapist@demo.local',
    demoPassword: 'Therapist123!',
  ),
  _LoginRoleOption(
    role: UserRole.agency,
    label: 'Agency',
    subtitle: 'Roster & operations',
    icon: Icons.business_outlined,
    gradient: AppGlossyGradients.tertiary,
    demoEmail: 'agency@demo.local',
    demoPassword: 'Agency123!',
  ),
  _LoginRoleOption(
    role: UserRole.admin,
    label: 'Admin',
    subtitle: 'Platform administration',
    icon: Icons.admin_panel_settings_outlined,
    gradient: AppGlossyGradients.warning,
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
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xs,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              alignment: Alignment.center,
              children: const [
                Align(
                  alignment: Alignment.centerRight,
                  child: AppThemeToggle(compact: true),
                ),
                Center(child: AppBrandLogo(size: AppBrandLogoSize.large)),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            const Center(
              child: AppHealthcareIllustration(
                type: AppIllustrationType.family,
                size: 64,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
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
        const SizedBox(height: AppSpacing.md),
        _LoginRoleSelector(
          roles: _loginRoles,
          selectedRole: _selectedRole,
          onSelected: _selectRole,
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
        GlossyButton(
          title: 'Sign in',
          variant: GlossyButtonVariant.tealBlue,
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

class _LoginRoleSelector extends StatelessWidget {
  const _LoginRoleSelector({
    required this.roles,
    required this.selectedRole,
    required this.onSelected,
  });

  final List<_LoginRoleOption> roles;
  final UserRole selectedRole;
  final void Function(_LoginRoleOption option) onSelected;

  _LoginRoleOption get _selected => roles.firstWhere(
    (r) => r.role == selectedRole,
    orElse: () => roles.first,
  );

  Future<void> _openPicker(BuildContext context) async {
    final picked = await showModalBottomSheet<_LoginRoleOption>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _LoginRolePickerSheet(
        roles: roles,
        selectedRole: selectedRole,
      ),
    );
    if (picked != null) onSelected(picked);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _selected;

    return Semantics(
      button: true,
      label: 'Account type, ${selected.label}. Tap to change.',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openPicker(context),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'Account type',
              prefixIcon: Icon(selected.icon, color: scheme.primary),
              suffixIcon: const Icon(Icons.unfold_more_rounded),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 14,
              ),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                selected.label,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginRolePickerSheet extends StatefulWidget {
  const _LoginRolePickerSheet({
    required this.roles,
    required this.selectedRole,
  });

  final List<_LoginRoleOption> roles;
  final UserRole selectedRole;

  @override
  State<_LoginRolePickerSheet> createState() => _LoginRolePickerSheetState();
}

class _LoginRolePickerSheetState extends State<_LoginRolePickerSheet> {
  final _scrollController = ScrollController();
  late UserRole _highlightedRole;
  bool _canScrollDown = false;

  @override
  void initState() {
    super.initState();
    _highlightedRole = widget.selectedRole;
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    final canScroll = max > 0;
    final atBottom = _scrollController.offset >= max - 4;
    final nextCanScrollDown = canScroll && !atBottom;
    if (nextCanScrollDown != _canScrollDown) {
      setState(() => _canScrollDown = nextCanScrollDown);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              'Tap a role to select',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          SizedBox(
            height: 280,
            child: Stack(
              children: [
                ListView.separated(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: widget.roles.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final option = widget.roles[index];
                    final selected = option.role == _highlightedRole;

                    return _LoginRoleOptionTile(
                      option: option,
                      selected: selected,
                      compact: true,
                      onTap: () => Navigator.pop(context, option),
                    );
                  },
                ),
                if (_canScrollDown)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      child: Container(
                        height: 28,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              scheme.surface.withValues(alpha: 0),
                              scheme.surface,
                            ],
                          ),
                        ),
                        alignment: Alignment.bottomCenter,
                        child: Icon(
                          Icons.expand_more_rounded,
                          size: 18,
                          color: scheme.primary.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginRoleOptionTile extends StatelessWidget {
  const _LoginRoleOptionTile({
    required this.option,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final _LoginRoleOption option;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shadowColor = AppGlossyGradients.baseShadowColor(option.gradient);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: compact ? AppSpacing.sm : AppSpacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            gradient: selected ? option.gradient : null,
            color: selected
                ? null
                : scheme.surfaceContainerHighest.withValues(alpha: 0.55),
            border: Border.all(
              color: selected
                  ? Colors.white.withValues(alpha: 0.4)
                  : scheme.outlineVariant.withValues(alpha: 0.5),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: shadowColor.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: compact ? 36 : 44,
                height: compact ? 36 : 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? Colors.white.withValues(alpha: 0.22)
                      : scheme.surface,
                ),
                child: Icon(
                  option.icon,
                  size: compact ? 18 : 22,
                  color: selected ? Colors.white : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.label,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      option.subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: selected
                            ? Colors.white.withValues(alpha: 0.88)
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? Colors.white : scheme.outlineVariant,
              ),
            ],
          ),
        ),
      ),
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

