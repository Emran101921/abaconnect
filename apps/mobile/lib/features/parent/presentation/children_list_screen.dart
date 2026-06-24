import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../../marketplace/data/marketplace_repository.dart';
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
      AppSnackBar.showError(
        context,
        'Please complete all required fields before saving.',
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
        AppSnackBar.showError(
          context,
          'Could not save child profile: ${AppSnackBar.messageFromError(e)}',
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
                  child: GlossyButton(
                    title: widget.existing == null
                        ? 'Save & continue'
                        : 'Save',
                    variant: GlossyButtonVariant.greenTeal,
                    loading: _saving,
                    onPressed: _save,
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
      final list = await ref
          .read(parentBookingRepositoryProvider)
          .fetchChildren();
      if (mounted) {
        setState(() {
          _children = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        AppSnackBar.showError(
          context,
          'Could not load children: ${AppSnackBar.messageFromError(e)}',
        );
      }
    }
  }

  Future<void> _addChild() async {
    final child = await showChildProfileSheet(context);
    if (child == null) return;
    await _load();
    if (mounted) {
      AppSnackBar.showSuccess(
        context,
        'Child saved — opening intake screening…',
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
      AppSnackBar.showSuccess(context, 'Child profile updated.');
    }
  }

  String _marketplaceSubtitle(MarketplaceRequestModel? request) {
    if (request == null) return 'No marketplace request';
    if (request.pendingInterestCount > 0) {
      return 'Active request · ${request.pendingInterestCount} provider${request.pendingInterestCount == 1 ? '' : 's'} to review';
    }
    return switch (request.status) {
      'ACTIVE' => 'Active marketplace request',
      'PAUSED' => 'Marketplace request paused',
      'CLOSED' => 'Marketplace request closed',
      _ => 'Marketplace request · ${request.status.toLowerCase()}',
    };
  }

  Future<void> _openMarketplaceForChild(
    MarketplaceRequestModel request,
  ) async {
    if (request.pendingInterestCount > 0) {
      await context.push(
        '${AppRoutes.parentMarketplace}/${request.id}/interests',
      );
    } else {
      await context.push(AppRoutes.parentMarketplace);
    }
    if (mounted) {
      ref.invalidate(parentMarketplaceRequestsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final marketplaceRequests = ref.watch(parentMarketplaceRequestsProvider);
    final requestsByChildId = marketplaceRequests.maybeWhen(
      data: (list) {
        final map = <String, MarketplaceRequestModel>{};
        for (final request in list) {
          final childId = request.childId;
          if (childId == null) continue;
          final existing = map[childId];
          if (existing == null ||
              request.pendingInterestCount > existing.pendingInterestCount) {
            map[childId] = request;
          }
        }
        return map;
      },
      orElse: () => <String, MarketplaceRequestModel>{},
    );

    return AppScaffold(
      title: 'My Children',
      subtitle: 'Child profiles for screening & care',
      bottomNavigationBar: const RoleBottomNav(
        current: CoreNavTab.profile,
      ),
      floatingActionButton: GlossyFab(
        icon: Icons.add,
        onPressed: _addChild,
        tooltip: 'Add child',
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _children.isEmpty
          ? AppContentContainer(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.child_care_outlined,
                      size: 56,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(height: 16),
                    const Text('No children yet'),
                    const SizedBox(height: 8),
                    GlossyButton(
                      title: 'Add child profile',
                      icon: Icons.add,
                      variant: GlossyButtonVariant.tealBlue,
                      onPressed: _addChild,
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: AppContentContainer(
                child: ListView.separated(
                  itemCount: _children.length,
                  separatorBuilder: (context, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final child = _children[index];
                    final request = requestsByChildId[child.id];
                    final hasPendingReview =
                        (request?.pendingInterestCount ?? 0) > 0;
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(child.firstName.characters.first),
                        ),
                        title: Text(child.displayName),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'DOB ${DateFormat.yMMMd().format(child.dateOfBirth)}'
                              '${child.primaryLanguage != null ? ' · ${child.primaryLanguage}' : ''}',
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _marketplaceSubtitle(request),
                              style: TextStyle(
                                color: hasPendingReview
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.outline,
                                fontWeight: hasPendingReview
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (request != null)
                              IconButton(
                                tooltip: hasPendingReview
                                    ? 'Review providers'
                                    : 'View marketplace request',
                                icon: Icon(
                                  hasPendingReview
                                      ? Icons.verified_user_outlined
                                      : Icons.storefront_outlined,
                                  color: hasPendingReview
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                                ),
                                onPressed: () =>
                                    _openMarketplaceForChild(request),
                              ),
                            IconButton(
                              tooltip: 'Edit child profile',
                              icon: const Icon(Icons.edit),
                              onPressed: () => _editChild(child),
                            ),
                          ],
                        ),
                        onTap: () => context.push(
                          '${AppRoutes.parentChildren}/${child.id}',
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
    );
  }
}
