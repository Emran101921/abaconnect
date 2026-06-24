import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../../service_coordinator/presentation/sc_providers.dart';

class AgencyAddServiceCoordinatorScreen extends ConsumerStatefulWidget {
  const AgencyAddServiceCoordinatorScreen({super.key});

  @override
  ConsumerState<AgencyAddServiceCoordinatorScreen> createState() =>
      _AgencyAddServiceCoordinatorScreenState();
}

class _AgencyAddServiceCoordinatorScreenState
    extends ConsumerState<AgencyAddServiceCoordinatorScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  final _languages = TextEditingController();
  final _notes = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _languages.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await ref.read(serviceCoordinatorRepositoryProvider).createServiceCoordinator(
        email: _email.text.trim(),
        password: _password.text,
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        languages: _languages.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
      ref.invalidate(agencyRosterMembersProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Service coordinator added to roster')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Add service coordinator',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Service coordinators cannot self-register. Add them here to place them on your official agency roster.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _firstName,
            decoration: const InputDecoration(labelText: 'First name'),
          ),
          TextField(
            controller: _lastName,
            decoration: const InputDecoration(labelText: 'Last name'),
          ),
          TextField(
            controller: _email,
            decoration: const InputDecoration(labelText: 'Email'),
            keyboardType: TextInputType.emailAddress,
          ),
          TextField(
            controller: _password,
            decoration: const InputDecoration(labelText: 'Temporary password'),
            obscureText: true,
          ),
          TextField(
            controller: _phone,
            decoration: const InputDecoration(labelText: 'Phone'),
          ),
          TextField(
            controller: _languages,
            decoration: const InputDecoration(
              labelText: 'Languages (comma-separated)',
            ),
          ),
          TextField(
            controller: _notes,
            decoration: const InputDecoration(labelText: 'Notes'),
            maxLines: 2,
          ),
          const SizedBox(height: 24),
          GlossyButton(
            title: _submitting ? 'Creating…' : 'Add to roster',
            icon: Icons.person_add_outlined,
            onPressed: _submitting ? null : _submit,
          ),
        ],
      ),
    );
  }
}
