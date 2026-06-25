import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../data/service_coordinator_repository.dart';
import 'sc_providers.dart';

class ScFollowUpsScreen extends ConsumerStatefulWidget {
  const ScFollowUpsScreen({super.key, this.initialSearchQuery});

  final String? initialSearchQuery;

  @override
  ConsumerState<ScFollowUpsScreen> createState() => _ScFollowUpsScreenState();
}

class _ScFollowUpsScreenState extends ConsumerState<ScFollowUpsScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: widget.initialSearchQuery ?? '',
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ScFollowUpModel> _filter(List<ScFollowUpModel> list) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return list;
    return list.where((f) {
      final haystack = '${f.childName} ${f.type}'.toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final followUps = ref.watch(scFollowUpsProvider);

    return AppScaffold(
      title: 'Follow-up reminders',
      body: followUps.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) {
          final filtered = _filter(list);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Search follow-ups',
                  hintText: 'Child name or reminder type…',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              if (list.isEmpty)
                const Center(child: Text('No follow-ups scheduled.'))
              else if (filtered.isEmpty)
                const Center(child: Text('No follow-ups match your search.'))
              else
                ...filtered.map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      color: f.overdue
                          ? Theme.of(context).colorScheme.errorContainer
                          : null,
                      child: ListTile(
                        leading: Icon(
                          f.overdue ? Icons.warning_amber : Icons.event,
                          color: f.overdue ? Colors.red : null,
                        ),
                        title: Text(f.childName),
                        subtitle: Text(
                          '${f.type} · ${DateFormat.yMMMd().format(f.dueDate)}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push(
                          '${AppRoutes.serviceCoordinatorHome}/cases/${f.childId}',
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
