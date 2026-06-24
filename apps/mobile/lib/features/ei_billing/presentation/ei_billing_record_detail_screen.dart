import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../shared/layout/dashboard_card.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/app_status_badge.dart';
import '../../../shared/widgets/app_trust_notice.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../data/ei_billing_repository.dart';
import 'ei_billing_shell_screen.dart';

class EiBillingRecordDetailScreen extends ConsumerStatefulWidget {
  const EiBillingRecordDetailScreen({
    super.key,
    required this.recordId,
    this.canSubmitClaims = false,
    this.canManageBilling = false,
    this.baseRoute,
  });

  final String recordId;
  final bool canSubmitClaims;
  final bool canManageBilling;
  final String? baseRoute;

  @override
  ConsumerState<EiBillingRecordDetailScreen> createState() =>
      _EiBillingRecordDetailScreenState();
}

class _EiBillingRecordDetailScreenState
    extends ConsumerState<EiBillingRecordDetailScreen> {
  bool _busy = false;

  Future<void> _refreshRecord() async {
    ref.invalidate(eiBillingRecordProvider(widget.recordId));
    ref.invalidate(eiBillingQueueProvider(null));
    await ref.read(eiBillingRecordProvider(widget.recordId).future);
  }

  Future<void> _lockForBilling(EiBillingRecordModel row) async {
    final sessionId = row.sessionId;
    if (sessionId == null) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(eiBillingRepositoryProvider)
          .lockSessionForBilling(sessionId);
      await _refreshRecord();
      if (mounted) {
        AppSnackBar.showSuccess(
          context,
          'Session note locked for billing review.',
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          'Could not lock session: ${AppSnackBar.messageFromError(e)}',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _validate() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(eiBillingRepositoryProvider)
          .validateRecord(widget.recordId);
      await _refreshRecord();
      if (mounted) {
        AppSnackBar.showSuccess(context, 'Validation complete.');
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          'Validation failed: ${AppSnackBar.messageFromError(e)}',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _transition(String targetStatus) async {
    setState(() => _busy = true);
    try {
      await ref.read(eiBillingRepositoryProvider).transitionQueue(
            widget.recordId,
            targetStatus,
          );
      await _refreshRecord();
      if (mounted) {
        AppSnackBar.showSuccess(context, 'Moved to $targetStatus.');
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          'Could not advance queue: ${AppSnackBar.messageFromError(e)}',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirmAuthorizedAction(String actionLabel) async {
    var confirmed = false;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Authorized $actionLabel'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppTrustNotice(
                    dense: true,
                    message:
                        'Explicit authorization is required before transmitting Medicaid EI claims. No auto-submit.',
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: confirmed,
                    onChanged: (value) =>
                        setDialogState(() => confirmed = value ?? false),
                    title: Text(
                      'I am authorized to $actionLabel this EI claim.',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: confirmed ? () => Navigator.pop(ctx, true) : null,
                  child: Text(actionLabel),
                ),
              ],
            );
          },
        );
      },
    );
    return result ?? false;
  }

  Future<void> _export() async {
    final workflow = await _pickWorkflow();
    if (workflow == null) return;
    final authorized = await _confirmAuthorizedAction('export');
    if (!authorized) return;

    setState(() => _busy = true);
    try {
      final result = await ref.read(eiBillingRepositoryProvider).exportRecord(
            recordId: widget.recordId,
            workflow: workflow,
            authorizedConfirm: true,
          );
      if (mounted) {
        AppSnackBar.showSuccess(
          context,
          'Exported ${result.fileName} (${result.artifactType}).',
        );
        await _showExportDialog(result);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          'Export failed: ${AppSnackBar.messageFromError(e)}',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showExportDialog(EiBillingExportResultModel result) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export ready'),
        content: SizedBox(
          width: double.maxFinite,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('File: ${result.fileName}'),
                Text('Type: ${result.artifactType}'),
                const SizedBox(height: 12),
                SizedBox(
                  height: 240,
                  child: SingleChildScrollView(
                    child: SelectableText(
                      result.payload,
                      style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                          ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: result.payload));
              if (ctx.mounted) {
                AppSnackBar.showSuccess(ctx, 'Copied to clipboard.');
              }
            },
            child: const Text('Copy to clipboard'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final workflow = await _pickWorkflow();
    if (workflow == null) return;
    final authorized = await _confirmAuthorizedAction('submit');
    if (!authorized) return;

    setState(() => _busy = true);
    try {
      final result = await ref.read(eiBillingRepositoryProvider).submitRecord(
            recordId: widget.recordId,
            workflow: workflow,
            authorizedConfirm: true,
          );
      await _refreshRecord();
      if (mounted) {
        AppSnackBar.showSuccess(
          context,
          result.accepted
              ? 'Submitted (${result.externalReferenceId}).'
              : result.message,
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          'Submission failed: ${AppSnackBar.messageFromError(e)}',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _pickWorkflow() async {
    return showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Clearinghouse workflow'),
        children: [
          for (final workflow in eiClearinghouseWorkflows)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, workflow),
              child: Text(workflow),
            ),
        ],
      ),
    );
  }

  Future<void> _showDenialSheet() async {
    final codeController = TextEditingController();
    final reasonController = TextEditingController();
    final payerController = TextEditingController();
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(ctx).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Record denial',
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: codeController,
                  decoration: const InputDecoration(labelText: 'Denial code'),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(labelText: 'Reason'),
                  maxLines: 3,
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: payerController,
                  decoration: const InputDecoration(labelText: 'Payer name'),
                ),
              ),
              const SizedBox(height: 16),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: GlossyButton(
                    title: 'Save denial',
                    variant: GlossyButtonVariant.greenTeal,
                    onPressed: () => Navigator.pop(ctx, true),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (saved != true) return;
    if (codeController.text.trim().isEmpty ||
        reasonController.text.trim().isEmpty) {
      if (mounted) {
        AppSnackBar.showError(context, 'Code and reason are required.');
      }
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(eiBillingRepositoryProvider).recordDenial(
            recordId: widget.recordId,
            code: codeController.text.trim(),
            reason: reasonController.text.trim(),
            payerName: payerController.text.trim().isEmpty
                ? null
                : payerController.text.trim(),
          );
      await _refreshRecord();
      if (mounted) AppSnackBar.showSuccess(context, 'Denial recorded.');
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          'Could not record denial: ${AppSnackBar.messageFromError(e)}',
        );
      }
    } finally {
      codeController.dispose();
      reasonController.dispose();
      payerController.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showPaymentSheet() async {
    final paidController = TextEditingController();
    final allowedController = TextEditingController();
    final eftController = TextEditingController();
    final eraController = TextEditingController();
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(ctx).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Record payment',
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: paidController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Paid amount'),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: allowedController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Allowed amount'),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: eftController,
                  decoration: const InputDecoration(labelText: 'EFT reference'),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: eraController,
                  decoration: const InputDecoration(
                    labelText: 'ERA / 835 reference (optional)',
                    hintText: 'Trace number or file reference',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Full ERA import is not yet available — this reference is stored as a placeholder.',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
              const SizedBox(height: 16),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: GlossyButton(
                    title: 'Post payment',
                    variant: GlossyButtonVariant.greenTeal,
                    onPressed: () => Navigator.pop(ctx, true),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (saved != true) return;
    final paid = double.tryParse(paidController.text.trim());
    if (paid == null) {
      if (mounted) AppSnackBar.showError(context, 'Enter a valid paid amount.');
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(eiBillingRepositoryProvider).recordPayment(
            recordId: widget.recordId,
            paidAmount: paid,
            allowedAmount: double.tryParse(allowedController.text.trim()),
            eftReference: eftController.text.trim().isEmpty
                ? null
                : eftController.text.trim(),
            eraPlaceholder: eraController.text.trim().isEmpty
                ? null
                : eraController.text.trim(),
          );
      await _refreshRecord();
      if (mounted) AppSnackBar.showSuccess(context, 'Payment posted.');
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          'Could not post payment: ${AppSnackBar.messageFromError(e)}',
        );
      }
    } finally {
      paidController.dispose();
      allowedController.dispose();
      eftController.dispose();
      eraController.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final record = ref.watch(eiBillingRecordProvider(widget.recordId));
    return AppScaffold(
      title: 'EI billing record',
      subtitle: widget.recordId,
      showPageBreadcrumbs: true,
      body: record.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Unable to load record: $e')),
        data: (row) {
          final transitions =
              eiBillingQueueTransitions[row.queueStatus] ?? const <String>[];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DashboardCard(
                title: row.childDisplayName ?? 'Child',
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppStatusBadge.fromKind(
                        eiStatusKind(row.queueStatus),
                        label: row.queueStatus,
                      ),
                      const SizedBox(height: 12),
                      Text('Provider: ${row.therapistName ?? '—'}'),
                      Text(
                        'Service date: ${DateFormat.yMMMd().format(row.serviceDate)}',
                      ),
                      Text('Units: ${row.units}'),
                      if (row.submittedAt != null)
                        Text(
                          'Submitted: ${DateFormat.yMMMd().format(row.submittedAt!)}',
                        ),
                      if (row.externalReferenceId != null)
                        Text('Reference: ${row.externalReferenceId}'),
                      if (row.sessionId != null) ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () {
                            final prefix =
                                widget.baseRoute?.contains('/admin') == true
                                    ? AppRoutes.adminHome
                                    : AppRoutes.agencyHome;
                            context.push(
                              '$prefix/session-notes/${row.sessionId}/form',
                            );
                          },
                          icon: const Icon(Icons.description_outlined),
                          label: const Text('View session note'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (row.denials.isNotEmpty) ...[
                const SizedBox(height: 16),
                DashboardCard(
                  title: 'Denials',
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        for (final denial in row.denials)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.gavel_outlined),
                            title: Text('${denial.code} — ${denial.reason}'),
                            subtitle: Text(
                              [
                                if (denial.payerName != null)
                                  'Payer: ${denial.payerName}',
                                'Status: ${denial.correctionStatus}',
                                if (denial.receivedAt != null)
                                  'Received: ${DateFormat.yMMMd().format(denial.receivedAt!)}',
                              ].join(' · '),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
              if (row.payments.isNotEmpty) ...[
                const SizedBox(height: 16),
                DashboardCard(
                  title: 'Payments',
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        for (final payment in row.payments)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.payments_outlined),
                            title: Text(
                              NumberFormat.currency(symbol: r'$')
                                  .format(payment.paidAmount),
                            ),
                            subtitle: Text(
                              [
                                if (payment.allowedAmount != null)
                                  'Allowed: ${NumberFormat.currency(symbol: r'$').format(payment.allowedAmount)}',
                                'Status: ${payment.reconciliationStatus}',
                                if (payment.eftReference != null)
                                  'EFT: ${payment.eftReference}',
                                'Posted: ${DateFormat.yMMMd().format(payment.postedAt)}',
                              ].join(' · '),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              DashboardCard(
                title: 'Validation issues',
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: row.validationIssues.isEmpty
                      ? const Text('No open validation issues.')
                      : Column(
                          children: [
                            for (final issue in row.validationIssues)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(
                                  issue.resolved
                                      ? Icons.check_circle_outline
                                      : Icons.error_outline,
                                  color: issue.resolved
                                      ? Colors.green
                                      : Theme.of(context).colorScheme.error,
                                ),
                                title: Text(issue.code),
                                subtitle: Text(issue.message),
                                trailing: Text(issue.severity),
                              ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),
              GlossyButton(
                title: 'Run validation',
                variant: GlossyButtonVariant.bluePurple,
                loading: _busy,
                onPressed: _validate,
              ),
              if (transitions.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Advance queue',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final status in transitions)
                      OutlinedButton(
                        onPressed: _busy ? null : () => _transition(status),
                        child: Text(status),
                      ),
                  ],
                ),
              ],
              if (widget.canSubmitClaims) ...[
                const SizedBox(height: 16),
                GlossyButton(
                  title: 'Export claim',
                  variant: GlossyButtonVariant.greenTeal,
                  loading: _busy,
                  onPressed: _export,
                ),
                const SizedBox(height: 8),
                GlossyButton(
                  title: 'Submit claim',
                  variant: GlossyButtonVariant.greenTeal,
                  loading: _busy,
                  onPressed: _submit,
                ),
              ],
              if (widget.canManageBilling) ...[
                if (row.sessionId != null && row.lockedAt == null) ...[
                  const SizedBox(height: 16),
                  GlossyButton(
                    title: 'Lock session note for billing',
                    variant: GlossyButtonVariant.orangeRed,
                    loading: _busy,
                    onPressed: () => _lockForBilling(row),
                  ),
                ],
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _showDenialSheet,
                  icon: const Icon(Icons.gavel_outlined),
                  label: const Text('Record denial'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _showPaymentSheet,
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('Record payment'),
                ),
              ],
              if (widget.baseRoute != null) ...[
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => context.go(widget.baseRoute!),
                  child: const Text('Back to EI billing'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
