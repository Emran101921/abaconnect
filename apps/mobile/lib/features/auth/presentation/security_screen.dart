import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/providers/consent_gate_provider.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/models/user_role.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../data/auth_repository.dart';

final mfaStatusProvider = FutureProvider<bool>((ref) async {
  return ref.watch(authRepositoryProvider).fetchMfaStatus();
});

final trustedDevicesProvider = FutureProvider<List<TrustedDevice>>((ref) async {
  return ref.watch(authRepositoryProvider).fetchTrustedDevices();
});

class SecurityScreen extends ConsumerStatefulWidget {
  const SecurityScreen({super.key});

  @override
  ConsumerState<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends ConsumerState<SecurityScreen> {
  String? _setupSecret;
  String? _setupUrl;

  Future<void> _beginSetup() async {
    try {
      final setup = await ref.read(authRepositoryProvider).beginMfaSetup();
      setState(() {
        _setupSecret = setup.secret;
        _setupUrl = setup.otpauthUrl;
      });
      ref.invalidate(mfaStatusProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          const SnackBar(content: Text('MFA setup failed. Please try again.')),
        );
      }
    }
  }

  Future<void> _enable(String code) async {
    try {
      await ref.read(authRepositoryProvider).enableMfa(code);
      setState(() {
        _setupSecret = null;
        _setupUrl = null;
      });
      ref.invalidate(mfaStatusProvider);
      ref.invalidate(trustedDevicesProvider);
      // Clear the onboarding MFA gate so the router can advance the user.
      ref.read(mfaEnabledProvider.notifier).state = true;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Two-factor authentication enabled')),
        );
        // If MFA was required to finish onboarding, continue to the home tab.
        final session = ref.read(authStateProvider).valueOrNull;
        if (session != null && roleRequiresOnboarding(session.user.role)) {
          context.go(session.user.role.homeRoute);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Enable failed: $e')));
      }
    }
  }

  Future<void> _disable() async {
    final codeController = TextEditingController();
    final passwordController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disable MFA'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeController,
              decoration: const InputDecoration(
                labelText: 'Authenticator code',
              ),
            ),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          GlossyButton(
            title: 'Disable',
            size: GlossyButtonSize.small,
            fullWidth: false,
            variant: GlossyButtonVariant.redDarkRed,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(authRepositoryProvider)
          .disableMfa(
            code: codeController.text.trim(),
            password: passwordController.text,
          );
      ref.invalidate(mfaStatusProvider);
      ref.read(mfaEnabledProvider.notifier).state = false;
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('MFA disabled')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Disable failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mfa = ref.watch(mfaStatusProvider);
    final devices = ref.watch(trustedDevicesProvider);
    final session = ref.watch(authStateProvider).valueOrNull;
    final role = session?.user.role;
    final isParent = role == UserRole.parent;
    final isTherapist = role == UserRole.therapist;
    final onboardingRole =
        session != null && roleRequiresOnboarding(session.user.role);
    final mfaPending = !ref.watch(mfaEnabledProvider);
    final dateFormat = DateFormat.yMMMd().add_jm();

    return AppScaffold(
      title: 'Security',
      showBackButton: false,
      bottomNavigationBar: (isParent || isTherapist)
          ? const RoleBottomNav(current: CoreNavTab.profile)
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        children: [
          if (onboardingRole && mfaPending) ...[
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Two-factor authentication is required to finish '
                        'setting up your account. Set it up below to continue.',
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          mfa.when(
            data: (enabled) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Two-factor authentication',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        enabled
                            ? 'MFA is on. Sign-in requires your authenticator app.'
                            : 'Add an extra layer of security with Google Authenticator or similar.',
                      ),
                      const SizedBox(height: 16),
                      if (enabled && !onboardingRole)
                        GlossyOutlinedButton(
                          onPressed: _disable,
                          child: const Text('Disable MFA'),
                        )
                      else if (enabled && onboardingRole)
                        Text(
                          'Two-factor authentication is required for your '
                          'account type and cannot be disabled.',
                          style: Theme.of(context).textTheme.bodySmall,
                        )
                      else if (_setupSecret == null)
                        GlossyButton(
                          title: 'Set up MFA',
                          variant: GlossyButtonVariant.bluePurple,
                          onPressed: _beginSetup,
                        )
                      else ...[
                        const Text('Scan this URL in your authenticator app:'),
                        const SizedBox(height: 8),
                        SelectableText(_setupUrl ?? _setupSecret!),
                        const SizedBox(height: 8),
                        SelectableText('Secret: $_setupSecret'),
                        const SizedBox(height: 12),
                        _EnableMfaForm(onEnable: _enable),
                      ],
                    ],
                  ),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
          ),
          const SizedBox(height: 16),
          Text(
            'Trusted devices',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Devices verified with MFA. Each sign-in records the device model, '
            'IP address, and approximate location.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          devices.when(
            data: (list) {
              if (list.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No trusted devices yet. Complete MFA setup to register '
                      'this device.',
                    ),
                  ),
                );
              }
              return Column(
                children: list.map((device) {
                  final label = [
                    device.deviceModel,
                    device.platform,
                  ].where((part) => part != null && part.isNotEmpty).join(' · ');
                  return Card(
                    child: ListTile(
                      leading: Icon(
                        device.trusted
                            ? Icons.verified_user
                            : Icons.phonelink_setup,
                        color: device.trusted ? Colors.green : Colors.grey,
                      ),
                      title: Text(label.isEmpty ? 'Unknown device' : label),
                      subtitle: Text(
                        [
                          if (device.lastLocation != null)
                            device.lastLocation,
                          if (device.lastIp != null) 'IP ${device.lastIp}',
                          'Last seen ${dateFormat.format(device.lastSeenAt.toLocal())}',
                        ].join(' · '),
                      ),
                      isThreeLine: true,
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Could not load devices: $e'),
          ),
          const SizedBox(height: 32),
          GlossyButton.logOut(
            onPressed: () async {
              await ref.read(authStateProvider.notifier).logout();
              if (context.mounted) context.go(AppRoutes.login);
            },
          ),
        ],
      ),
    );
  }
}

class _EnableMfaForm extends StatefulWidget {
  const _EnableMfaForm({required this.onEnable});

  final Future<void> Function(String code) onEnable;

  @override
  State<_EnableMfaForm> createState() => _EnableMfaFormState();
}

class _EnableMfaFormState extends State<_EnableMfaForm> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (kDebugMode) ...[
          const Text(
            'Local dev: use 000000 when DEV_MFA_BYPASS_CODE is set in api/.env',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 8),
        ],
        Row(
      children: [
        Expanded(
          child: TextField(
            controller: _code,
            decoration: const InputDecoration(
              labelText: 'Verification code',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GlossyButton(
          title: 'Enable',
          size: GlossyButtonSize.small,
          fullWidth: false,
          variant: GlossyButtonVariant.greenTeal,
          onPressed: () => widget.onEnable(_code.text.trim()),
        ),
      ],
        ),
      ],
    );
  }
}
