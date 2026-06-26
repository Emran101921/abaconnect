import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/location/location_service.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/layout/dashboard_card.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/app_status_badge.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../data/parent_booking_repository.dart';
import '../../agency_platform/widgets/bloomora_compliance_disclaimer.dart';

final parentPendingSignaturesProvider =
    FutureProvider<List<PendingSessionSignatureModel>>((ref) async {
  return ref.watch(parentBookingRepositoryProvider).fetchPendingSignatures();
});

final parentSessionNoteReviewProvider =
    FutureProvider.family<ParentSessionNoteReviewModel?, String>((
  ref,
  sessionId,
) async {
  return ref
      .watch(parentBookingRepositoryProvider)
      .fetchSessionNoteForSign(sessionId);
});

class ParentSessionSignScreen extends ConsumerStatefulWidget {
  const ParentSessionSignScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<ParentSessionSignScreen> createState() =>
      _ParentSessionSignScreenState();
}

class _ParentSessionSignScreenState
    extends ConsumerState<ParentSessionSignScreen> {
  final _nameCtrl = TextEditingController();
  var _signing = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final review = ref.watch(parentSessionNoteReviewProvider(widget.sessionId));

    return AppScaffold(
      title: 'Sign session note',
      subtitle: 'Secure remote signature',
      showPageBreadcrumbs: true,
      body: review.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(AppSnackBar.messageFromError(e))),
        data: (note) {
          if (note == null) {
            return const Center(child: Text('Session note not found'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const BloomoraComplianceDisclaimer(dense: true),
              const SizedBox(height: 16),
              DashboardCard(
                title: note.childName,
                subtitle: note.sessionDate,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Provider: ${note.therapistName}'),
                    if (note.serviceType != null)
                      Text('Service: ${note.serviceType}'),
                    if (note.timeFrom != null && note.timeTo != null)
                      Text('Time: ${note.timeFrom} – ${note.timeTo}'),
                    const SizedBox(height: 12),
                    if (note.therapistSigned)
                      AppStatusBadge.fromKind(
                        AppStatusKind.approved,
                        label: 'Provider signed',
                      ),
                    if (note.parentSigned)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: AppStatusBadge.fromKind(
                          AppStatusKind.completed,
                          label: 'Already signed',
                        ),
                      ),
                  ],
                ),
              ),
              if (note.sessionDescription != null) ...[
                const SizedBox(height: 16),
                DashboardCard(
                  title: 'Session summary',
                  child: Text(note.sessionDescription!),
                ),
              ],
              if (!note.parentSigned && note.readyForParentSignature) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Your full name (signature) *',
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                GlossyButton(
                  title: _signing ? 'Signing…' : 'Sign with location verification',
                  icon: Icons.draw_outlined,
                  onPressed: _signing ? null : () => _sign(note),
                ),
              ],
              if (!note.readyForParentSignature && !note.parentSigned)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Text(
                    'This session note is not ready for signature yet. '
                    'Your provider will notify you when it is available.',
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _sign(ParentSessionNoteReviewModel note) async {
    final name = _nameCtrl.text.trim();
    if (name.length < 2) {
      AppSnackBar.showError(context, 'Enter your full name to sign.');
      return;
    }
    setState(() => _signing = true);
    try {
      final result = await LocationService().captureCurrentPosition();
      if (!result.isSuccess) {
        if (mounted) {
          await LocationService.showLocationRequiredDialog(
            context,
            result.failureReason ?? LocationFailure.permissionDenied,
          );
        }
        setState(() => _signing = false);
        return;
      }
      final signed = await ref
          .read(parentBookingRepositoryProvider)
          .signSessionNote(
            sessionId: widget.sessionId,
            signatureName: name,
            latitude: result.latitude!,
            longitude: result.longitude!,
          );
      ref.invalidate(parentPendingSignaturesProvider);
      ref.invalidate(parentSessionNoteReviewProvider(widget.sessionId));
      if (!mounted) return;
      AppSnackBar.showSuccess(
        context,
        signed.fullySigned
            ? 'Session note fully signed. Thank you!'
            : 'Signature recorded.',
      );
      context.go(AppRoutes.parentHome);
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, e);
    } finally {
      if (mounted) setState(() => _signing = false);
    }
  }
}

class ParentPendingSignaturesBanner extends ConsumerWidget {
  const ParentPendingSignaturesBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(parentPendingSignaturesProvider);
    return pending.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        final first = list.first;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Card(
            color: Theme.of(context)
                .colorScheme
                .primaryContainer
                .withValues(alpha: 0.45),
            child: ListTile(
              leading: const Icon(Icons.draw_outlined),
              title: Text(
                '${list.length} session note${list.length == 1 ? '' : 's'} awaiting your signature',
              ),
              subtitle: Text(
                'Next: ${first.childName} · ${first.therapistName}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(
                AppRoutes.parentSessionSign(first.sessionId),
              ),
            ),
          ),
        );
      },
    );
  }
}

class ParentPendingSignaturesScreen extends ConsumerWidget {
  const ParentPendingSignaturesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(parentPendingSignaturesProvider);
    final dateFmt = DateFormat.yMMMd();

    return AppScaffold(
      title: 'Signatures needed',
      showPageBreadcrumbs: true,
      body: pending.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Text('No session notes awaiting your signature.'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = list[index];
              return Card(
                child: ListTile(
                  title: Text(item.childName),
                  subtitle: Text(
                    '${item.therapistName}'
                    '${item.sessionDate != null ? ' · ${dateFmt.format(DateTime.parse(item.sessionDate!))}' : ''}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(
                    AppRoutes.parentSessionSign(item.sessionId),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
