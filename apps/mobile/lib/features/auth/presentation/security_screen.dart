import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';

final mfaStatusProvider = FutureProvider<bool>((ref) async {
  return ref.watch(authRepositoryProvider).fetchMfaStatus();
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Setup failed: $e')),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Two-factor authentication enabled')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Enable failed: $e')),
        );
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
              decoration: const InputDecoration(labelText: 'Authenticator code'),
            ),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Disable')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(authRepositoryProvider).disableMfa(
            code: codeController.text.trim(),
            password: passwordController.text,
          );
      ref.invalidate(mfaStatusProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('MFA disabled')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Disable failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mfa = ref.watch(mfaStatusProvider);

    return AppScaffold(
      title: 'Security',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
                      if (enabled)
                        OutlinedButton(
                          onPressed: _disable,
                          child: const Text('Disable MFA'),
                        )
                      else if (_setupSecret == null)
                        FilledButton(
                          onPressed: _beginSetup,
                          child: const Text('Set up MFA'),
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
    return Row(
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
        FilledButton(
          onPressed: () => widget.onEnable(_code.text.trim()),
          child: const Text('Enable'),
        ),
      ],
    );
  }
}
