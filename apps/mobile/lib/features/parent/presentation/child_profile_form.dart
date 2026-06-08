import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/app_dashboard_card.dart';
import '../../../shared/widgets/app_section_header.dart';
import '../data/parent_booking_repository.dart';

Future<DateTime?> pickChildDateOfBirth(BuildContext context, DateTime initial) {
  return showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(1990),
    lastDate: DateTime.now(),
    helpText: 'Date of birth',
  );
}

class ChildProfileFormData {
  ChildProfileFormData({
    this.firstName = '',
    this.lastName = '',
    DateTime? dateOfBirth,
    this.gender,
    this.primaryLanguage,
    this.guardianName,
    this.guardianPhone,
    this.guardianEmail,
    this.addressLine1,
    this.zipCode,
    this.pediatricianName,
    this.insuranceType,
    this.hadEarlyIntervention,
  }) : dateOfBirth = dateOfBirth ?? DateTime(2018, 1, 1);

  String firstName;
  String lastName;
  DateTime dateOfBirth;
  String? gender;
  String? primaryLanguage;
  String? guardianName;
  String? guardianPhone;
  String? guardianEmail;
  String? addressLine1;
  String? zipCode;
  String? pediatricianName;
  String? insuranceType;
  bool? hadEarlyIntervention;

  factory ChildProfileFormData.fromChild(ChildModel child) {
    return ChildProfileFormData(
      firstName: child.firstName,
      lastName: child.lastName,
      dateOfBirth: child.dateOfBirth,
      gender: child.gender,
      primaryLanguage: child.primaryLanguage,
      guardianName: child.guardianName,
      guardianPhone: child.guardianPhone,
      guardianEmail: child.guardianEmail,
      addressLine1: child.addressLine1,
      zipCode: child.zipCode,
      pediatricianName: child.pediatricianName,
      insuranceType: child.insuranceType,
      hadEarlyIntervention: child.hadEarlyIntervention,
    );
  }

  bool get isValid =>
      firstName.trim().isNotEmpty &&
      lastName.trim().isNotEmpty &&
      gender != null &&
      primaryLanguage != null &&
      (guardianName?.trim().isNotEmpty ?? false) &&
      (guardianPhone?.trim().isNotEmpty ?? false) &&
      (guardianEmail?.trim().isNotEmpty ?? false) &&
      (addressLine1?.trim().isNotEmpty ?? false) &&
      (zipCode?.trim().isNotEmpty ?? false) &&
      hadEarlyIntervention != null;
}

class ChildProfileForm extends StatefulWidget {
  const ChildProfileForm({
    super.key,
    required this.data,
    required this.onChanged,
    this.readOnly = false,
  });

  final ChildProfileFormData data;
  final VoidCallback onChanged;
  final bool readOnly;

  @override
  State<ChildProfileForm> createState() => _ChildProfileFormState();
}

class _ChildProfileFormState extends State<ChildProfileForm> {
  static const _genders = ['Female', 'Male', 'Non-binary', 'Prefer not to say'];
  static const _languages = [
    'English',
    'Spanish',
    'Mandarin',
    'Vietnamese',
    'Arabic',
    'Other',
  ];
  static const _insuranceTypes = [
    'Private',
    'Medicaid',
    'CHIP',
    'Tricare',
    'Self-pay',
    'Other',
  ];

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppSectionHeader(
          title: 'Child information',
          subtitle: 'Basic details for screening and care',
        ),
        AppDashboardCard(
          elevated: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                enabled: !widget.readOnly,
                decoration: const InputDecoration(
                  labelText: 'First name *',
                  prefixIcon: Icon(Icons.child_care_outlined),
                ),
                controller: TextEditingController(text: data.firstName)
                  ..selection = TextSelection.collapsed(
                    offset: data.firstName.length,
                  ),
                onChanged: (v) {
                  data.firstName = v;
                  widget.onChanged();
                },
              ),
              const SizedBox(height: 12),
              TextField(
                enabled: !widget.readOnly,
                decoration: const InputDecoration(labelText: 'Last name *'),
                controller: TextEditingController(text: data.lastName)
                  ..selection = TextSelection.collapsed(
                    offset: data.lastName.length,
                  ),
                onChanged: (v) {
                  data.lastName = v;
                  widget.onChanged();
                },
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Date of birth *'),
                subtitle: Text(DateFormat.yMMMd().format(data.dateOfBirth)),
                trailing: const Icon(Icons.calendar_today),
                onTap: widget.readOnly
                    ? null
                    : () async {
                        final picked = await pickChildDateOfBirth(
                          context,
                          data.dateOfBirth,
                        );
                        if (picked != null) {
                          setState(() => data.dateOfBirth = picked);
                          widget.onChanged();
                        }
                      },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: data.gender,
                decoration: const InputDecoration(labelText: 'Gender'),
                items: _genders
                    .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                    .toList(),
                onChanged: widget.readOnly
                    ? null
                    : (v) {
                        setState(() => data.gender = v);
                        widget.onChanged();
                      },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: data.primaryLanguage,
                decoration: const InputDecoration(
                  labelText: 'Primary language',
                ),
                items: _languages
                    .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                    .toList(),
                onChanged: widget.readOnly
                    ? null
                    : (v) {
                        setState(() => data.primaryLanguage = v);
                        widget.onChanged();
                      },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const AppSectionHeader(
          title: 'Parent / guardian',
          subtitle: 'Primary contact for care coordination',
        ),
        AppDashboardCard(
          elevated: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                enabled: !widget.readOnly,
                decoration: const InputDecoration(
                  labelText: 'Guardian name *',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                controller: TextEditingController(text: data.guardianName ?? '')
                  ..selection = TextSelection.collapsed(
                    offset: (data.guardianName ?? '').length,
                  ),
                onChanged: (v) {
                  data.guardianName = v;
                  widget.onChanged();
                },
              ),
              const SizedBox(height: 12),
              TextField(
                enabled: !widget.readOnly,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone *',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                controller:
                    TextEditingController(text: data.guardianPhone ?? '')
                      ..selection = TextSelection.collapsed(
                        offset: (data.guardianPhone ?? '').length,
                      ),
                onChanged: (v) {
                  data.guardianPhone = v;
                  widget.onChanged();
                },
              ),
              const SizedBox(height: 12),
              TextField(
                enabled: !widget.readOnly,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email *',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                controller:
                    TextEditingController(text: data.guardianEmail ?? '')
                      ..selection = TextSelection.collapsed(
                        offset: (data.guardianEmail ?? '').length,
                      ),
                onChanged: (v) {
                  data.guardianEmail = v;
                  widget.onChanged();
                },
              ),
              const SizedBox(height: 12),
              TextField(
                enabled: !widget.readOnly,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  prefixIcon: Icon(Icons.home_outlined),
                ),
                controller: TextEditingController(text: data.addressLine1 ?? '')
                  ..selection = TextSelection.collapsed(
                    offset: (data.addressLine1 ?? '').length,
                  ),
                onChanged: (v) {
                  data.addressLine1 = v;
                  widget.onChanged();
                },
              ),
              const SizedBox(height: 12),
              TextField(
                enabled: !widget.readOnly,
                decoration: const InputDecoration(
                  labelText: 'ZIP code',
                  prefixIcon: Icon(Icons.pin_drop_outlined),
                ),
                controller: TextEditingController(text: data.zipCode ?? '')
                  ..selection = TextSelection.collapsed(
                    offset: (data.zipCode ?? '').length,
                  ),
                onChanged: (v) {
                  data.zipCode = v;
                  widget.onChanged();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const AppSectionHeader(
          title: 'Medical & insurance',
          subtitle: 'Helps match providers and coverage',
        ),
        AppDashboardCard(
          elevated: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                enabled: !widget.readOnly,
                decoration: const InputDecoration(
                  labelText: 'Pediatrician name',
                  prefixIcon: Icon(Icons.medical_services_outlined),
                ),
                controller:
                    TextEditingController(text: data.pediatricianName ?? '')
                      ..selection = TextSelection.collapsed(
                        offset: (data.pediatricianName ?? '').length,
                      ),
                onChanged: (v) {
                  data.pediatricianName = v;
                  widget.onChanged();
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: data.insuranceType,
                decoration: const InputDecoration(labelText: 'Insurance type'),
                items: _insuranceTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: widget.readOnly
                    ? null
                    : (v) {
                        setState(() => data.insuranceType = v);
                        widget.onChanged();
                      },
              ),
              const SizedBox(height: 12),
              Text(
                'Has your child received Early Intervention before?',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              SegmentedButton<bool?>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Yes')),
                  ButtonSegment(value: false, label: Text('No')),
                ],
                selected: {data.hadEarlyIntervention},
                emptySelectionAllowed: true,
                onSelectionChanged: widget.readOnly
                    ? null
                    : (selection) {
                        setState(() {
                          data.hadEarlyIntervention = selection.firstOrNull;
                        });
                        widget.onChanged();
                      },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
