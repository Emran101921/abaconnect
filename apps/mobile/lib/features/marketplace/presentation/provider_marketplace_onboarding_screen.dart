import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../../../shared/widgets/role_tab_scaffold.dart';
import '../data/marketplace_repository.dart';
import 'provider_marketplace_screen.dart';

const providerConfidentialityTerms =
    'I agree to maintain confidentiality of all marketplace service request '
    'information, use data only for authorized care coordination, and not '
    'disclose identifiable child or family information without documented parent consent.';

class ProviderMarketplaceOnboardingScreen extends ConsumerStatefulWidget {
  const ProviderMarketplaceOnboardingScreen({
    super.key,
    this.shell = MarketplaceProviderShell.therapist,
  });

  final MarketplaceProviderShell shell;

  @override
  ConsumerState<ProviderMarketplaceOnboardingScreen> createState() =>
      _ProviderMarketplaceOnboardingScreenState();
}

class _ProviderMarketplaceOnboardingScreenState
    extends ConsumerState<ProviderMarketplaceOnboardingScreen> {
  final _legalName = TextEditingController();
  final _displayName = TextEditingController();
  final _license = TextEditingController();
  final _npi = TextEditingController();
  final _zipCodes = TextEditingController(text: '11230, 11201');
  final _languages = TextEditingController(text: 'English');
  final _categories = <String>{
    'SPEECH',
    'ABA',
    'OT',
    'EVALUATION',
  };
  var _termsAccepted = false;
  var _saving = false;

  @override
  void dispose() {
    _legalName.dispose();
    _displayName.dispose();
    _license.dispose();
    _npi.dispose();
    _zipCodes.dispose();
    _languages.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Accept confidentiality terms to continue.')),
      );
      return;
    }
    if (_legalName.text.trim().isEmpty || _displayName.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Legal name and display name are required.')),
      );
      return;
    }
    final zipList = _zipCodes.text
        .split(',')
        .map((z) => z.trim())
        .where((z) => z.isNotEmpty)
        .toList();
    if (zipList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one coverage ZIP code.')),
      );
      return;
    }
    if (_categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one service category.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(marketplaceRepositoryProvider).completeProviderOnboarding(
            legalName: _legalName.text.trim(),
            displayName: _displayName.text.trim(),
            licenseNumber: _license.text.trim().isEmpty
                ? null
                : _license.text.trim(),
            npi: _npi.text.trim().isEmpty ? null : _npi.text.trim(),
            serviceCategories: _categories.toList(),
            coverageZipCodes: zipList,
            languages: _languages.text
                .split(',')
                .map((l) => l.trim())
                .where((l) => l.isNotEmpty)
                .toList(),
            confidentialityTermsAccepted: true,
            accountType: widget.shell == MarketplaceProviderShell.agency
                ? 'AGENCY'
                : 'THERAPIST',
          );
      ref.invalidate(providerMarketplaceProfileProvider);
      if (!mounted) return;
      context.go(
        widget.shell == MarketplaceProviderShell.agency
            ? AppRoutes.agencyMarketplace
            : AppRoutes.therapistMarketplace,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Onboarding failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = ListView(
      padding: const EdgeInsets.all(16),
      children: [
          const Text(
            'Complete your provider marketplace profile. You will only see '
            'anonymous service requests in your coverage ZIP codes until a parent '
            'grants consent to share identifiable information.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _legalName,
            decoration: const InputDecoration(labelText: 'Legal name *'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _displayName,
            decoration: const InputDecoration(labelText: 'Display name *'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _license,
            decoration: const InputDecoration(labelText: 'License number'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _npi,
            decoration: const InputDecoration(labelText: 'NPI'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _zipCodes,
            decoration: const InputDecoration(
              labelText: 'Coverage ZIP codes *',
              hintText: 'Comma-separated, e.g. 11230, 11201',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _languages,
            decoration: const InputDecoration(
              labelText: 'Languages',
              hintText: 'Comma-separated',
            ),
          ),
          const SizedBox(height: 12),
          Text('Service categories', style: Theme.of(context).textTheme.titleSmall),
          Wrap(
            spacing: 8,
            children: [
              'SPEECH',
              'ABA',
              'OT',
              'PT',
              'EVALUATION',
              'SPECIAL_INSTRUCTION',
              'NURSING',
              'FEEDING',
              'SOCIAL_WORK',
              'SERVICE_COORDINATION',
            ].map((cat) {
              final selected = _categories.contains(cat);
              return FilterChip(
                label: Text(cat.replaceAll('_', ' ')),
                selected: selected,
                onSelected: (v) {
                  setState(() {
                    if (v) {
                      _categories.add(cat);
                    } else {
                      _categories.remove(cat);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            value: _termsAccepted,
            onChanged: (v) => setState(() => _termsAccepted = v ?? false),
            title: const Text(providerConfidentialityTerms),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: 16),
          GlossyButton(
            title: 'Enable marketplace access',
            variant: GlossyButtonVariant.bluePurple,
            loading: _saving,
            onPressed: _submit,
          ),
        ],
    );

    return switch (widget.shell) {
      MarketplaceProviderShell.therapist => TherapistTabScaffold(
          title: 'Marketplace access',
          subtitle: 'Required before viewing anonymous requests',
          body: body,
        ),
      MarketplaceProviderShell.agency => AppScaffold(
          title: 'Marketplace access',
          subtitle: 'Required before viewing anonymous requests',
          body: body,
        ),
    };
  }
}
