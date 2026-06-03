import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/app_providers.dart';
import '../../../shared/models/user_role.dart';
import '../../../shared/widgets/app_scaffold.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController(text: 'parent@demo.local');
  final _passwordController = TextEditingController(text: 'Parent123!');
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
      final result = await ref.read(authStateProvider.notifier).login(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            role: demoRole ?? UserRole.parent,
          );
      if (!mounted) return;
      if (result.requiresMfa) {
        final code = await _promptMfaCode();
        if (code == null || !mounted) return;
        await ref.read(authStateProvider.notifier).completeMfaLogin(
              mfaChallengeToken: result.mfaChallengeToken!,
              code: code,
            );
      }
      if (!mounted) return;
      final session = ref.read(authStateProvider).value;
      if (session != null) {
        context.go(session.user.role.homeRoute);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String?> _promptMfaCode() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Authenticator code'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '6-digit code',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          maxLength: 6,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
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
    return AppScaffold(
      title: 'Sign In',
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Welcome to ABA Connect',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'API must be running at http://localhost:3000\n'
              'Check: http://localhost:3000/api/v1/health',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
              autofillHints: const [AutofillHints.password],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : () => _signIn(),
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Sign In'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.push('/register'),
              child: const Text('Create an account'),
            ),
            TextButton(
              onPressed: () => context.push('/forgot-password'),
              child: const Text('Forgot password?'),
            ),
            const Spacer(),
            Text(
              'Demo accounts (after db seed)',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: _loading
                      ? null
                      : () {
                          _emailController.text = 'parent@demo.local';
                          _passwordController.text = 'Parent123!';
                          _signIn(demoRole: UserRole.parent);
                        },
                  child: const Text('Parent demo'),
                ),
                OutlinedButton(
                  onPressed: _loading
                      ? null
                      : () {
                          _emailController.text = 'therapist@demo.local';
                          _passwordController.text = 'Therapist123!';
                          _signIn(demoRole: UserRole.therapist);
                        },
                  child: const Text('Therapist demo'),
                ),
                OutlinedButton(
                  onPressed: _loading
                      ? null
                      : () {
                          _emailController.text = 'admin@abaconnect.local';
                          _passwordController.text = 'Admin123!';
                          _signIn(demoRole: UserRole.admin);
                        },
                  child: const Text('Admin demo'),
                ),
                OutlinedButton(
                  onPressed: _loading
                      ? null
                      : () {
                          _emailController.text = 'agency@demo.local';
                          _passwordController.text = 'Agency123!';
                          _signIn(demoRole: UserRole.agency);
                        },
                  child: const Text('Agency demo'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
