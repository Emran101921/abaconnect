import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../data/parent_booking_repository.dart';

class ChildrenListScreen extends ConsumerStatefulWidget {
  const ChildrenListScreen({super.key});

  @override
  ConsumerState<ChildrenListScreen> createState() => _ChildrenListScreenState();
}

class _ChildrenListScreenState extends ConsumerState<ChildrenListScreen> {
  List<ChildModel> _children = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await ref.read(parentBookingRepositoryProvider).fetchChildren();
      if (mounted) {
        setState(() {
          _children = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load children: $e')),
        );
      }
    }
  }

  Future<void> _addChild() async {
    final firstName = TextEditingController();
    final lastName = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add child'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: firstName,
              decoration: const InputDecoration(labelText: 'First name'),
            ),
            TextField(
              controller: lastName,
              decoration: const InputDecoration(labelText: 'Last name'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true || firstName.text.isEmpty || lastName.text.isEmpty) {
      return;
    }
    try {
      await ref.read(parentBookingRepositoryProvider).addChild(
            firstName: firstName.text.trim(),
            lastName: lastName.text.trim(),
            dateOfBirth: DateTime(2018, 1, 1),
          );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Child added')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Add failed: $e')),
        );
      }
    }
  }

  Future<void> _editChild(ChildModel child) async {
    final firstName = TextEditingController(text: child.firstName);
    final lastName = TextEditingController(text: child.lastName);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit child'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: firstName,
              decoration: const InputDecoration(labelText: 'First name'),
            ),
            TextField(
              controller: lastName,
              decoration: const InputDecoration(labelText: 'Last name'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(parentBookingRepositoryProvider).updateChild(
            childId: child.id,
            firstName: firstName.text.trim(),
            lastName: lastName.text.trim(),
          );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Child updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'My Children',
      floatingActionButton: FloatingActionButton(
        onPressed: _addChild,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _children.isEmpty
              ? const Center(child: Text('No children yet. Tap + to add one.'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _children.length,
                    separatorBuilder: (context, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final child = _children[index];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(child.firstName.characters.first),
                          ),
                          title: Text(child.displayName),
                          subtitle: const Text('Tap to edit profile'),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _editChild(child),
                          ),
                          onTap: () => _editChild(child),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
