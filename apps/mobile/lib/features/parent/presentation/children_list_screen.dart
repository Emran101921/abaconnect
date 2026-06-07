import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../data/parent_booking_repository.dart';
import 'child_profile_form.dart';

Future<ChildModel?> showChildProfileSheet(
  BuildContext context, {
  ChildModel? existing,
}) {
  return showModalBottomSheet<ChildModel>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _ChildProfileSheet(existing: existing),
  );
}

class _ChildProfileSheet extends ConsumerStatefulWidget {
  const _ChildProfileSheet({this.existing});

  final ChildModel? existing;

  @override
  ConsumerState<_ChildProfileSheet> createState() => _ChildProfileSheetState();
}

class _ChildProfileSheetState extends ConsumerState<_ChildProfileSheet> {
  late final ChildProfileFormData _data;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _data = widget.existing != null
        ? ChildProfileFormData.fromChild(widget.existing!)
        : ChildProfileFormData();
  }

  Future<void> _save() async {
    if (!_data.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete required fields')),
      );
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(parentBookingRepositoryProvider);
    try {
      ChildModel child;
      if (widget.existing != null) {
        await repo.updateChild(
          childId: widget.existing!.id,
          firstName: _data.firstName.trim(),
          lastName: _data.lastName.trim(),
          dateOfBirth: _data.dateOfBirth,
          gender: _data.gender,
          primaryLanguage: _data.primaryLanguage,
          guardianName: _data.guardianName?.trim(),
          guardianPhone: _data.guardianPhone?.trim(),
          guardianEmail: _data.guardianEmail?.trim(),
          addressLine1: _data.addressLine1?.trim(),
          zipCode: _data.zipCode?.trim(),
          pediatricianName: _data.pediatricianName?.trim(),
          insuranceType: _data.insuranceType,
          hadEarlyIntervention: _data.hadEarlyIntervention,
        );
        child = ChildModel(
          id: widget.existing!.id,
          firstName: _data.firstName.trim(),
          lastName: _data.lastName.trim(),
          dateOfBirth: _data.dateOfBirth,
          gender: _data.gender,
          primaryLanguage: _data.primaryLanguage,
          guardianName: _data.guardianName,
          guardianPhone: _data.guardianPhone,
          guardianEmail: _data.guardianEmail,
          addressLine1: _data.addressLine1,
          zipCode: _data.zipCode,
          pediatricianName: _data.pediatricianName,
          insuranceType: _data.insuranceType,
          hadEarlyIntervention: _data.hadEarlyIntervention,
        );
      } else {
        child = await repo.addChild(
          firstName: _data.firstName.trim(),
          lastName: _data.lastName.trim(),
          dateOfBirth: _data.dateOfBirth,
          gender: _data.gender,
          primaryLanguage: _data.primaryLanguage,
          guardianName: _data.guardianName?.trim(),
          guardianPhone: _data.guardianPhone?.trim(),
          guardianEmail: _data.guardianEmail?.trim(),
          addressLine1: _data.addressLine1?.trim(),
          zipCode: _data.zipCode?.trim(),
          pediatricianName: _data.pediatricianName?.trim(),
          insuranceType: _data.insuranceType,
          hadEarlyIntervention: _data.hadEarlyIntervention,
        );
      }
      if (mounted) Navigator.pop(context, child);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text(
                      widget.existing == null ? 'Add child' : 'Edit child',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ChildProfileForm(
                    data: _data,
                    onChanged: () => setState(() {}),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(widget.existing == null ? 'Save & continue' : 'Save'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

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
    final child = await showChildProfileSheet(context);
    if (child == null) return;
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Child saved — opening intake screening…')),
      );
      context.push(
        '${AppRoutes.parentScreening}?childId=${child.id}&autoStart=true',
      );
    }
  }

  Future<void> _editChild(ChildModel child) async {
    final updated = await showChildProfileSheet(context, existing: child);
    if (updated == null) return;
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Child updated')),
      );
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
                          subtitle: Text(
                            'DOB ${DateFormat.yMMMd().format(child.dateOfBirth)}'
                            '${child.primaryLanguage != null ? ' · ${child.primaryLanguage}' : ''}',
                          ),
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
