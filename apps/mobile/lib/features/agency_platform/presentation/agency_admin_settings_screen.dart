import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/layout/dashboard_card.dart';
import '../../../shared/widgets/app_data_table.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../agency_platform_constants.dart';
import '../data/agency_platform_repository.dart';
import '../widgets/bloomora_compliance_disclaimer.dart';
import 'agency_platform_providers.dart';

class AgencyAdminSettingsScreen extends ConsumerStatefulWidget {
  const AgencyAdminSettingsScreen({super.key});

  @override
  ConsumerState<AgencyAdminSettingsScreen> createState() =>
      _AgencyAdminSettingsScreenState();
}

class _AgencyAdminSettingsScreenState
    extends ConsumerState<AgencyAdminSettingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final overview = ref.watch(agencyPlatformOverviewProvider);

    return AppScaffold(
      title: 'Admin settings',
      subtitle: 'Regions, programs, modules, and agency configuration',
      showPageBreadcrumbs: true,
      body: overview.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            AppSkeleton(height: 48),
            SizedBox(height: 16),
            AppSkeletonCard(lines: 5),
          ],
        ),
        error: (e, _) => Center(child: Text(AppSnackBar.messageFromError(e))),
        data: (data) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: const BloomoraComplianceDisclaimer(dense: true),
            ),
            TabBar(
              controller: _tabs,
              isScrollable: true,
              tabs: const [
                Tab(text: 'Branches & regions'),
                Tab(text: 'Departments'),
                Tab(text: 'Programs'),
                Tab(text: 'Feature modules'),
                Tab(text: 'Permissions'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _BranchesTab(overview: data),
                  _DepartmentsTab(overview: data),
                  _ProgramsTab(overview: data),
                  _ModulesTab(overview: data),
                  _PermissionsTab(overview: data),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BranchesTab extends ConsumerWidget {
  const _BranchesTab({required this.overview});

  final AgencyPlatformOverviewModel overview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: GlossyButton(
            title: 'Add branch',
            icon: Icons.add,
            onPressed: () => _showBranchDialog(context, ref),
          ),
        ),
        const SizedBox(height: 12),
        AppDataTable<AgencyBranchModel>(
          rows: overview.branches,
          searchPredicate: (row, q) =>
              row.name.toLowerCase().contains(q.toLowerCase()) ||
              (row.region ?? '').toLowerCase().contains(q.toLowerCase()),
          columns: [
            AppDataColumn(
              label: 'Branch',
              mobilePriority: true,
              cellBuilder: (_, row) => Text(row.name),
            ),
            AppDataColumn(
              label: 'Region',
              cellBuilder: (_, row) => Text(row.region ?? '—'),
            ),
            AppDataColumn(
              label: 'Location',
              cellBuilder: (_, row) => Text(
                [row.city, row.state, row.zipCode]
                    .where((e) => (e ?? '').isNotEmpty)
                    .join(', '),
              ),
            ),
            AppDataColumn(
              label: 'Status',
              cellBuilder: (_, row) => Text(row.active ? 'Active' : 'Inactive'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showBranchDialog(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    final regionCtrl = TextEditingController();
    final cityCtrl = TextEditingController();
    final stateCtrl = TextEditingController();
    final zipCtrl = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add office branch'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Branch name *'),
              ),
              TextField(
                controller: regionCtrl,
                decoration: const InputDecoration(labelText: 'Region'),
              ),
              TextField(
                controller: cityCtrl,
                decoration: const InputDecoration(labelText: 'City'),
              ),
              TextField(
                controller: stateCtrl,
                decoration: const InputDecoration(labelText: 'State'),
              ),
              TextField(
                controller: zipCtrl,
                decoration: const InputDecoration(labelText: 'ZIP code'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved != true || nameCtrl.text.trim().isEmpty) return;
    try {
      await ref.read(agencyPlatformRepositoryProvider).upsertBranch(
            name: nameCtrl.text.trim(),
            region: regionCtrl.text.trim().isEmpty
                ? null
                : regionCtrl.text.trim(),
            city:
                cityCtrl.text.trim().isEmpty ? null : cityCtrl.text.trim(),
            state:
                stateCtrl.text.trim().isEmpty ? null : stateCtrl.text.trim(),
            zipCode: zipCtrl.text.trim().isEmpty ? null : zipCtrl.text.trim(),
          );
      ref.invalidate(agencyPlatformOverviewProvider);
      if (context.mounted) {
        AppSnackBar.showSuccess(context, 'Branch saved.');
      }
    } catch (e) {
      if (context.mounted) AppSnackBar.showError(context, e);
    }
  }
}

class _DepartmentsTab extends ConsumerWidget {
  const _DepartmentsTab({required this.overview});

  final AgencyPlatformOverviewModel overview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: GlossyButton(
            title: 'Add department',
            icon: Icons.add,
            onPressed: () => _showDepartmentDialog(context, ref, overview),
          ),
        ),
        const SizedBox(height: 12),
        AppDataTable<AgencyDepartmentModel>(
          rows: overview.departments,
          searchPredicate: (row, q) =>
              row.name.toLowerCase().contains(q.toLowerCase()),
          columns: [
            AppDataColumn(
              label: 'Department',
              mobilePriority: true,
              cellBuilder: (_, row) => Text(row.name),
            ),
            AppDataColumn(
              label: 'Code',
              cellBuilder: (_, row) => Text(row.code ?? '—'),
            ),
            AppDataColumn(
              label: 'Branch',
              cellBuilder: (_, row) {
                final branch = overview.branches
                    .where((b) => b.id == row.branchId)
                    .map((b) => b.name)
                    .firstOrNull;
                return Text(branch ?? 'All branches');
              },
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showDepartmentDialog(
    BuildContext context,
    WidgetRef ref,
    AgencyPlatformOverviewModel overview,
  ) async {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    String? branchId;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Add department'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name *'),
              ),
              TextField(
                controller: codeCtrl,
                decoration: const InputDecoration(labelText: 'Code'),
              ),
              if (overview.branches.isNotEmpty)
                DropdownButtonFormField<String?>(
                  value: branchId,
                  decoration: const InputDecoration(labelText: 'Branch'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All')),
                    for (final b in overview.branches)
                      DropdownMenuItem(value: b.id, child: Text(b.name)),
                  ],
                  onChanged: (v) => setState(() => branchId = v),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (saved != true || nameCtrl.text.trim().isEmpty) return;
    try {
      await ref.read(agencyPlatformRepositoryProvider).upsertDepartment(
            branchId: branchId,
            name: nameCtrl.text.trim(),
            code: codeCtrl.text.trim().isEmpty ? null : codeCtrl.text.trim(),
          );
      ref.invalidate(agencyPlatformOverviewProvider);
      if (context.mounted) {
        AppSnackBar.showSuccess(context, 'Department saved.');
      }
    } catch (e) {
      if (context.mounted) AppSnackBar.showError(context, e);
    }
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}

class _ProgramsTab extends ConsumerWidget {
  const _ProgramsTab({required this.overview});

  final AgencyPlatformOverviewModel overview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: GlossyButton(
            title: 'Add program',
            icon: Icons.add,
            onPressed: () => _showProgramDialog(context, ref),
          ),
        ),
        const SizedBox(height: 12),
        AppDataTable<AgencyProgramModel>(
          rows: overview.programs,
          searchPredicate: (row, q) =>
              row.name.toLowerCase().contains(q.toLowerCase()),
          columns: [
            AppDataColumn(
              label: 'Program',
              mobilePriority: true,
              cellBuilder: (_, row) => Text(row.name),
            ),
            AppDataColumn(
              label: 'Service type',
              cellBuilder: (_, row) => Text(row.serviceType ?? '—'),
            ),
            AppDataColumn(
              label: 'Region',
              cellBuilder: (_, row) => Text(row.region ?? '—'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showProgramDialog(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    final regionCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add program'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Program name *'),
            ),
            TextField(
              controller: regionCtrl,
              decoration: const InputDecoration(labelText: 'Region'),
            ),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved != true || nameCtrl.text.trim().isEmpty) return;
    try {
      await ref.read(agencyPlatformRepositoryProvider).upsertProgram(
            name: nameCtrl.text.trim(),
            region: regionCtrl.text.trim().isEmpty
                ? null
                : regionCtrl.text.trim(),
            description:
                descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
          );
      ref.invalidate(agencyPlatformOverviewProvider);
      if (context.mounted) {
        AppSnackBar.showSuccess(context, 'Program saved.');
      }
    } catch (e) {
      if (context.mounted) AppSnackBar.showError(context, e);
    }
  }
}

class _ModulesTab extends ConsumerWidget {
  const _ModulesTab({required this.overview});

  final AgencyPlatformOverviewModel overview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DashboardCard(
          title: 'Modular features',
          subtitle:
              'Enable or disable platform modules per agency program needs.',
          child: Column(
            children: [
              for (final module in overview.modules)
                SwitchListTile(
                  title: Text(
                    AgencyPlatformModules.labels[module.moduleKey] ??
                        module.label,
                  ),
                  subtitle: Text(module.moduleKey),
                  value: module.enabled,
                  onChanged: (enabled) async {
                    try {
                      await ref
                          .read(agencyPlatformRepositoryProvider)
                          .updateFeatureModule(
                            moduleKey: module.moduleKey,
                            enabled: enabled,
                          );
                      ref.invalidate(agencyPlatformOverviewProvider);
                    } catch (e) {
                      if (context.mounted) AppSnackBar.showError(context, e);
                    }
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PermissionsTab extends StatelessWidget {
  const _PermissionsTab({required this.overview});

  final AgencyPlatformOverviewModel overview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DashboardCard(
          title: 'Role & scope permissions',
          subtitle:
              'Manage permissions by department, program, role, or individual user.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Permission grants configured: ${overview.permissionGrants.length}',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'Granular permission overrides (department, program, role, and '
                'user scopes) are stored in the agency platform settings. '
                'Use this panel to review grants; advanced editing expands in '
                'a later release.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              if (overview.permissionGrants.isNotEmpty) ...[
                const SizedBox(height: 16),
                for (final grant in overview.permissionGrants)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(grant.permission),
                    subtitle: Text(
                      '${grant.scopeType}${grant.scopeId != null ? ' · ${grant.scopeId}' : ''}',
                    ),
                    trailing: Icon(
                      grant.granted ? Icons.check_circle : Icons.cancel,
                      color: grant.granted
                          ? theme.colorScheme.primary
                          : theme.colorScheme.error,
                    ),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        DashboardCard(
          title: 'Program-specific settings',
          subtitle: 'Custom fields, billing rules, templates, and deadlines',
          child: Text(
            'Stored configuration keys: ${overview.settings.keys.join(', ')}',
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
