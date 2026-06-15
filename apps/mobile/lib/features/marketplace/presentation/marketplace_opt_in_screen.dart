import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../../../shared/widgets/role_tab_scaffold.dart';
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
  MarketplaceRequestModel? _postedRequest;

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
      final request = await ref.read(marketplaceRepositoryProvider).createRequest(
            childId: widget.childId,
            screeningResponseId: widget.screeningResponseId,
            anonymousConsentGranted: true,
            locationType: _locationType,
            languagePreference: widget.languagePreference,
            urgency: _urgency,
          );
      if (!mounted) return;
      setState(() => _postedRequest = request);
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

  Widget _buildSuccessBody(BuildContext context) {
    final request = _postedRequest!;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 56,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Request posted anonymously',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ref ${request.anonymousPublicId} · ${request.serviceAreaLabel}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What happens next',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Verified providers and agencies in your service area can respond '
                    'without seeing your child\'s identity. When someone is interested, '
                    'you\'ll get a notification and can review them before sharing any '
                    'contact details or documents.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          GlossyButton(
            title: 'Go to marketplace dashboard',
            icon: Icons.dashboard_outlined,
            variant: GlossyButtonVariant.tealBlue,
            onPressed: () => context.go(AppRoutes.parentMarketplace),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => context.go(AppRoutes.parentHome),
              child: const Text('Back to home'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return ParentTabScaffold(
      title: 'Anonymous marketplace',
      subtitle: _postedRequest == null
          ? 'Share general service needs only'
          : 'Request posted',
      body: _postedRequest != null
          ? _buildSuccessBody(context)
          : SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _consent,
                  onChanged: (v) => setState(() => _consent = v ?? false),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _consent = !_consent),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        anonymousMarketplaceConsentText,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GlossyButton(
              title: 'Post anonymous service request',
              loading: _submitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
