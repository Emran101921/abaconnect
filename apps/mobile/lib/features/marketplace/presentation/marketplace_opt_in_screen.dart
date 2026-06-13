import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../data/marketplace_repository.dart';

const anonymousMarketplaceConsentText =
    'I agree to create an anonymous service request in the provider marketplace. '
    'My child\'s name, contact information, exact address, documents, and private health '
    'details will not be shared unless I approve a specific provider or agency.';

class MarketplaceOptInScreen extends ConsumerStatefulWidget {
  const MarketplaceOptInScreen({
    super.key,
    required this.childId,
    this.screeningResponseId,
    this.languagePreference,
  });

  final String childId;
  final String? screeningResponseId;
  final String? languagePreference;

  @override
  ConsumerState<MarketplaceOptInScreen> createState() =>
      _MarketplaceOptInScreenState();
}

class _MarketplaceOptInScreenState extends ConsumerState<MarketplaceOptInScreen> {
  var _consent = false;
  var _submitting = false;
  String _locationType = 'HOME';
  String _urgency = 'ROUTINE';

  Future<void> _submit() async {
    if (widget.childId.isEmpty) {
      AppSnackBar.showError(
        context,
        'Child profile is missing. Go back and select a child first.',
      );
      return;
    }
    if (!_consent) {
      AppSnackBar.showError(
        context,
        'Please accept the anonymous marketplace consent.',
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(marketplaceRepositoryProvider).createRequest(
            childId: widget.childId,
            screeningResponseId: widget.screeningResponseId,
            anonymousConsentGranted: true,
            locationType: _locationType,
            languagePreference: widget.languagePreference,
            urgency: _urgency,
          );
      if (!mounted) return;
      AppSnackBar.showSuccess(
        context,
        'Anonymous service request posted to the marketplace.',
      );
      context.go(AppRoutes.parentMarketplace);
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          'Could not create request: ${AppSnackBar.messageFromError(e)}',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Anonymous marketplace',
      subtitle: 'Share general service needs only',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Possible service categories to explore may be suggested from your '
                'screening answers. Recommended next step: professional evaluation/referral. '
                'This is not a diagnosis.',
              ),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _locationType,
            decoration: const InputDecoration(
              labelText: 'Preferred service location',
            ),
            items: const [
              DropdownMenuItem(value: 'HOME', child: Text('Home')),
              DropdownMenuItem(value: 'DAYCARE', child: Text('Daycare')),
              DropdownMenuItem(value: 'CLINIC', child: Text('Clinic')),
              DropdownMenuItem(value: 'TELEHEALTH', child: Text('Telehealth')),
              DropdownMenuItem(value: 'SCHOOL', child: Text('School')),
              DropdownMenuItem(value: 'COMMUNITY', child: Text('Community')),
            ],
            onChanged: (v) => setState(() => _locationType = v ?? 'HOME'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _urgency,
            decoration: const InputDecoration(labelText: 'Urgency'),
            items: const [
              DropdownMenuItem(value: 'ROUTINE', child: Text('Routine')),
              DropdownMenuItem(value: 'SOON', child: Text('Soon')),
              DropdownMenuItem(value: 'URGENT', child: Text('Urgent')),
            ],
            onChanged: (v) => setState(() => _urgency = v ?? 'ROUTINE'),
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            value: _consent,
            onChanged: (v) => setState(() => _consent = v ?? false),
            title: const Text(anonymousMarketplaceConsentText),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Post anonymous service request'),
          ),
        ],
      ),
    );
  }
}
