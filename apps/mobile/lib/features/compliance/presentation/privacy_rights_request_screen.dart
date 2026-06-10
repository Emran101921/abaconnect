import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';

enum PrivacyRightsFormType {
  recordAccess('RECORD_ACCESS', 'Request My Records'),
  correction('CORRECTION', 'Request Correction'),
  restriction('RESTRICTION', 'Request Restriction'),
  confidentialCommunication(
    'CONFIDENTIAL_COMMUNICATION',
    'Request Confidential Communication',
  ),
  accountingOfDisclosures(
    'ACCOUNTING_OF_DISCLOSURES',
    'Accounting of Disclosures',
  ),
  contactPrivacyOfficer('CONTACT_PRIVACY_OFFICER', 'Contact Privacy Officer'),
  dataDeletion('DATA_DELETION', 'Delete Account / Data Request');

  const PrivacyRightsFormType(this.apiType, this.title);
  final String apiType;
  final String title;
}

class PrivacyRightsRequestScreen extends ConsumerStatefulWidget {
  const PrivacyRightsRequestScreen({super.key, required this.formType});

  final PrivacyRightsFormType formType;

  @override
  ConsumerState<PrivacyRightsRequestScreen> createState() =>
      _PrivacyRightsRequestScreenState();
}

class _PrivacyRightsRequestScreenState
    extends ConsumerState<PrivacyRightsRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  bool _submitting = false;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _c(String key) =>
      _controllers.putIfAbsent(key, TextEditingController.new);

  List<Widget> _fields() {
    switch (widget.formType) {
      case PrivacyRightsFormType.recordAccess:
        return [
          _field('fullName', 'Your name', required: true),
          _field('dateOfBirth', 'Date of birth (YYYY-MM-DD)', required: true),
          _field('email', 'Email', required: true),
          _field('phone', 'Phone'),
          _field('recordTypes', 'Type of records requested', required: true),
          _field('dateRange', 'Date range'),
          _dropdown(
            'deliveryMethod',
            'Delivery method',
            ['secure_app', 'encrypted_email', 'mail', 'pickup'],
          ),
          _field('notes', 'Notes', maxLines: 3),
        ];
      case PrivacyRightsFormType.correction:
        return [
          _field('recordToCorrect', 'Record to correct', required: true),
          _field('whatIsWrong', 'What is wrong', required: true, maxLines: 3),
          _field(
            'requestedCorrection',
            'Requested correction',
            required: true,
            maxLines: 3,
          ),
          _field('supportingDocumentNote', 'Supporting document notes'),
        ];
      case PrivacyRightsFormType.restriction:
        return [
          _field(
            'informationToRestrict',
            'What information should be restricted',
            required: true,
            maxLines: 3,
          ),
          _field('whoShouldNotReceive', 'Who should not receive it'),
          _field('reason', 'Reason', maxLines: 3),
        ];
      case PrivacyRightsFormType.confidentialCommunication:
        return [
          _dropdown(
            'preferredContactMethod',
            'Preferred contact method',
            ['phone', 'email', 'mail'],
          ),
          _field('preferredContact', 'Preferred phone/email/address'),
          _field('bestTimeToContact', 'Best time to contact'),
          _field('safetyNotes', 'Safety/privacy notes', maxLines: 3),
        ];
      case PrivacyRightsFormType.accountingOfDisclosures:
        return [
          _field('dateRange', 'Date range', required: true),
          _field(
            'disclosureTypes',
            'Type of disclosures requested',
            required: true,
          ),
        ];
      case PrivacyRightsFormType.contactPrivacyOfficer:
        return [
          _field('subject', 'Subject', required: true),
          _field('message', 'Message', required: true, maxLines: 5),
          _field('preferredContact', 'How we should reach you'),
        ];
      case PrivacyRightsFormType.dataDeletion:
        return [
          _field('reason', 'Reason for request', maxLines: 3),
          _field('confirmEmail', 'Confirm account email', required: true),
        ];
    }
  }

  Widget _field(
    String key,
    String label, {
    bool required = false,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: _c(key),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        maxLines: maxLines,
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
            : null,
      ),
    );
  }

  Widget _dropdown(String key, String label, List<String> options) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: options
            .map((o) => DropdownMenuItem(value: o, child: Text(o)))
            .toList(),
        onChanged: (v) => _c(key).text = v ?? '',
        validator: (v) => v == null ? 'Required' : null,
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _submitting) return;
    setState(() => _submitting = true);
    final payload = <String, dynamic>{};
    for (final entry in _controllers.entries) {
      final value = entry.value.text.trim();
      if (value.isNotEmpty) payload[entry.key] = value;
    }
    try {
      await ref.read(privacyRepositoryProvider).submitRightsRequest(
            requestType: widget.formType.apiType,
            payload: payload,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Request submitted. Our privacy team will respond per HIPAA timelines.',
          ),
        ),
      );
      Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not submit request.')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: widget.formType.title,
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Submit this form to exercise your HIPAA privacy rights. '
              'We will review your request and respond as required by law.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ..._fields(),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}
