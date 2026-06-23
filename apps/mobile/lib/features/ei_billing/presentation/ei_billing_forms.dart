import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/app_trust_notice.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../../agency/data/agency_repository.dart';
import '../../agency/presentation/agency_profile_screen.dart';
import '../../agency/presentation/agency_providers.dart';
import '../data/ei_billing_repository.dart';

Future<EiAgencyBillingProfileModel?> showEiAgencyProfileSheet(
  BuildContext context, {
  EiAgencyBillingProfileModel? existing,
}) {
  return showModalBottomSheet<EiAgencyBillingProfileModel>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _EiAgencyProfileSheet(existing: existing),
  );
}

Future<EiProviderEnrollmentModel?> showEiProviderEnrollmentSheet(
  BuildContext context, {
  EiProviderEnrollmentModel? existing,
}) {
  return showModalBottomSheet<EiProviderEnrollmentModel>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _EiProviderEnrollmentSheet(existing: existing),
  );
}

Future<EiCaseBillingProfileModel?> showEiCaseBillingSheet(
  BuildContext context, {
  String? childId,
  String? childDisplayName,
  EiCaseBillingProfileModel? existing,
}) {
  return showModalBottomSheet<EiCaseBillingProfileModel>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _EiCaseBillingSheet(
      childId: childId,
      childDisplayName: childDisplayName,
      existing: existing,
    ),
  );
}

Future<EiClearinghouseConfigModel?> showEiClearinghouseConfigSheet(
  BuildContext context, {
  EiClearinghouseConfigModel? existing,
}) {
  return showModalBottomSheet<EiClearinghouseConfigModel>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _EiClearinghouseConfigSheet(existing: existing),
  );
}

class _EiAgencyProfileSheet extends ConsumerStatefulWidget {
  const _EiAgencyProfileSheet({this.existing});

  final EiAgencyBillingProfileModel? existing;

  @override
  ConsumerState<_EiAgencyProfileSheet> createState() =>
      _EiAgencyProfileSheetState();
}

class _EiAgencyProfileSheetState extends ConsumerState<_EiAgencyProfileSheet> {
  late final TextEditingController _legalName;
  late final TextEditingController _npi;
  late final TextEditingController _medicaidProviderId;
  late final TextEditingController _ein;
  late final TextEditingController _etin;
  late final TextEditingController _eiHubReferenceId;
  late final TextEditingController _city;
  late final TextEditingController _state;
  late final TextEditingController _zipCode;
  late bool _enrollmentComplete;
  DateTime? _baaSignedAt;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _legalName = TextEditingController(text: existing?.legalName ?? '');
    _npi = TextEditingController(text: existing?.npi ?? '');
    _medicaidProviderId =
        TextEditingController(text: existing?.medicaidProviderId ?? '');
    _ein = TextEditingController(text: existing?.ein ?? '');
    _etin = TextEditingController(text: existing?.etin ?? '');
    _eiHubReferenceId =
        TextEditingController(text: existing?.eiHubReferenceId ?? '');
    _city = TextEditingController(text: existing?.city ?? '');
    _state = TextEditingController(text: existing?.state ?? 'NY');
    _zipCode = TextEditingController();
    _enrollmentComplete = existing?.enrollmentComplete ?? false;
    _baaSignedAt = existing?.baaSignedAt;
  }

  @override
  void dispose() {
    _legalName.dispose();
    _npi.dispose();
    _medicaidProviderId.dispose();
    _ein.dispose();
    _etin.dispose();
    _eiHubReferenceId.dispose();
    _city.dispose();
    _state.dispose();
    _zipCode.dispose();
    super.dispose();
  }

  Future<void> _pickBaaDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _baaSignedAt ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _baaSignedAt = picked);
  }

  Future<void> _save() async {
    if (_legalName.text.trim().isEmpty) {
      AppSnackBar.showError(context, 'Legal name is required.');
      return;
    }
    setState(() => _saving = true);
    try {
      final profile = await ref.read(eiBillingRepositoryProvider).upsertAgencyProfile(
            legalName: _legalName.text.trim(),
            npi: _npi.text.trim().isEmpty ? null : _npi.text.trim(),
            medicaidProviderId: _medicaidProviderId.text.trim().isEmpty
                ? null
                : _medicaidProviderId.text.trim(),
            ein: _ein.text.trim().isEmpty ? null : _ein.text.trim(),
            etin: _etin.text.trim().isEmpty ? null : _etin.text.trim(),
            eiHubReferenceId: _eiHubReferenceId.text.trim().isEmpty
                ? null
                : _eiHubReferenceId.text.trim(),
            enrollmentComplete: _enrollmentComplete,
            baaSignedAt: _baaSignedAt,
            city: _city.text.trim().isEmpty ? null : _city.text.trim(),
            state: _state.text.trim().isEmpty ? null : _state.text.trim(),
            zipCode: _zipCode.text.trim().isEmpty ? null : _zipCode.text.trim(),
          );
      ref.invalidate(eiAgencyBillingProfileProvider);
      if (mounted) Navigator.pop(context, profile);
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          'Could not save agency profile: ${AppSnackBar.messageFromError(e)}',
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
                      'Agency billing profile',
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
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: AppTrustNotice.protectedInfo(dense: true),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _legalName,
                        decoration: const InputDecoration(
                          labelText: 'Legal name *',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _npi,
                        decoration: const InputDecoration(labelText: 'NPI'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _medicaidProviderId,
                        decoration: const InputDecoration(
                          labelText: 'Medicaid provider ID',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _ein,
                        decoration: const InputDecoration(labelText: 'EIN'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _etin,
                        decoration: const InputDecoration(labelText: 'ETIN'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _eiHubReferenceId,
                        decoration: const InputDecoration(
                          labelText: 'EI-Hub reference ID',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _city,
                              decoration: const InputDecoration(labelText: 'City'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 80,
                            child: TextField(
                              controller: _state,
                              decoration: const InputDecoration(labelText: 'State'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 100,
                            child: TextField(
                              controller: _zipCode,
                              decoration: const InputDecoration(labelText: 'ZIP'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('BAA signed date'),
                        subtitle: Text(
                          _baaSignedAt != null
                              ? DateFormat.yMMMd().format(_baaSignedAt!)
                              : 'Not set',
                        ),
                        trailing: TextButton(
                          onPressed: _pickBaaDate,
                          child: const Text('Pick date'),
                        ),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Enrollment complete'),
                        value: _enrollmentComplete,
                        onChanged: (value) =>
                            setState(() => _enrollmentComplete = value),
                      ),
                    ],
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: GlossyButton(
                    title: 'Save profile',
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

class _EiProviderEnrollmentSheet extends ConsumerStatefulWidget {
  const _EiProviderEnrollmentSheet({this.existing});

  final EiProviderEnrollmentModel? existing;

  @override
  ConsumerState<_EiProviderEnrollmentSheet> createState() =>
      _EiProviderEnrollmentSheetState();
}

class _EiProviderEnrollmentSheetState
    extends ConsumerState<_EiProviderEnrollmentSheet> {
  AgencyTherapistModel? _selectedTherapist;
  late final TextEditingController _renderingNpi;
  late final TextEditingController _discipline;
  late final TextEditingController _eiCategory;
  String _medicaidEnrollmentStatus = 'ENROLLED';
  String _credentialStatus = 'ACTIVE';
  late bool _isActive;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _renderingNpi = TextEditingController(text: existing?.renderingNpi ?? '');
    _discipline = TextEditingController(text: existing?.discipline ?? '');
    _eiCategory = TextEditingController(text: existing?.eiCategory ?? '');
    _medicaidEnrollmentStatus =
        existing?.medicaidEnrollmentStatus ?? 'ENROLLED';
    _credentialStatus = existing?.credentialStatus ?? 'ACTIVE';
    _isActive = existing?.isActive ?? true;
  }

  @override
  void dispose() {
    _renderingNpi.dispose();
    _discipline.dispose();
    _eiCategory.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final therapistId =
        widget.existing?.therapistId ?? _selectedTherapist?.id;
    if (therapistId == null) {
      AppSnackBar.showError(context, 'Select a provider to enroll.');
      return;
    }
    setState(() => _saving = true);
    try {
      final enrollment =
          await ref.read(eiBillingRepositoryProvider).upsertProviderEnrollment(
                therapistId: therapistId,
                renderingNpi: _renderingNpi.text.trim().isEmpty
                    ? null
                    : _renderingNpi.text.trim(),
                discipline: _discipline.text.trim().isEmpty
                    ? null
                    : _discipline.text.trim(),
                eiCategory: _eiCategory.text.trim().isEmpty
                    ? null
                    : _eiCategory.text.trim(),
                medicaidEnrollmentStatus: _medicaidEnrollmentStatus,
                credentialStatus: _credentialStatus,
                isActive: _isActive,
              );
      ref.invalidate(eiProviderEnrollmentsProvider);
      if (mounted) Navigator.pop(context, enrollment);
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          'Could not save enrollment: ${AppSnackBar.messageFromError(e)}',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final therapists = ref.watch(agencyTherapistsProvider);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
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
                      widget.existing == null
                          ? 'Enroll provider'
                          : 'Edit provider enrollment',
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
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      if (widget.existing == null)
                        therapists.when(
                          loading: () => const LinearProgressIndicator(),
                          error: (e, _) => Text('Unable to load roster: $e'),
                          data: (rows) => DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'Provider *',
                            ),
                            initialValue: _selectedTherapist?.id,
                            items: rows
                                .map(
                                  (row) => DropdownMenuItem(
                                    value: row.id,
                                    child: Text(row.displayName),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedTherapist = rows.firstWhere(
                                  (row) => row.id == value,
                                );
                              });
                            },
                          ),
                        )
                      else
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(widget.existing!.therapistName),
                          subtitle: const Text('Rendering provider'),
                        ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _renderingNpi,
                        decoration: const InputDecoration(labelText: 'Rendering NPI'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _discipline,
                        decoration: const InputDecoration(labelText: 'Discipline'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _eiCategory,
                        decoration: const InputDecoration(labelText: 'EI category'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Medicaid enrollment',
                        ),
                        initialValue: _medicaidEnrollmentStatus,
                        items: const [
                          DropdownMenuItem(
                            value: 'ENROLLED',
                            child: Text('Enrolled'),
                          ),
                          DropdownMenuItem(
                            value: 'PENDING',
                            child: Text('Pending'),
                          ),
                          DropdownMenuItem(
                            value: 'NOT_ENROLLED',
                            child: Text('Not enrolled'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _medicaidEnrollmentStatus = value);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Credential status',
                        ),
                        initialValue: _credentialStatus,
                        items: const [
                          DropdownMenuItem(
                            value: 'ACTIVE',
                            child: Text('Active'),
                          ),
                          DropdownMenuItem(
                            value: 'PENDING',
                            child: Text('Pending'),
                          ),
                          DropdownMenuItem(
                            value: 'INACTIVE',
                            child: Text('Inactive'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _credentialStatus = value);
                          }
                        },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Active for billing'),
                        value: _isActive,
                        onChanged: (value) => setState(() => _isActive = value),
                      ),
                    ],
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: GlossyButton(
                    title: 'Save enrollment',
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

class _EiCaseBillingSheet extends ConsumerStatefulWidget {
  const _EiCaseBillingSheet({
    this.childId,
    this.childDisplayName,
    this.existing,
  });

  final String? childId;
  final String? childDisplayName;
  final EiCaseBillingProfileModel? existing;

  @override
  ConsumerState<_EiCaseBillingSheet> createState() =>
      _EiCaseBillingSheetState();
}

class _EiCaseBillingSheetState extends ConsumerState<_EiCaseBillingSheet> {
  String? _selectedChildId;
  String? _selectedChildName;
  late final TextEditingController _eiCaseId;
  late final TextEditingController _municipality;
  late final TextEditingController _ifspAuthorizationNumber;
  late final TextEditingController _serviceType;
  late final TextEditingController _medicaidCin;
  late final TextEditingController _placeOfService;
  String _consentStatus = 'GRANTED';
  DateTime? _authorizationStartDate;
  DateTime? _authorizationEndDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedChildId = widget.childId ?? widget.existing?.childId;
    _selectedChildName =
        widget.childDisplayName ?? widget.existing?.childDisplayName;
    final existing = widget.existing;
    _eiCaseId = TextEditingController(text: existing?.eiCaseId ?? '');
    _municipality = TextEditingController(text: existing?.municipality ?? '');
    _ifspAuthorizationNumber = TextEditingController(
      text: existing?.ifspAuthorizationNumber ?? '',
    );
    _serviceType = TextEditingController(text: existing?.serviceType ?? '');
    _medicaidCin = TextEditingController(text: existing?.medicaidCin ?? '');
    _placeOfService =
        TextEditingController(text: existing?.placeOfService ?? 'HOME');
    _consentStatus = existing?.consentStatus ?? 'GRANTED';
    _authorizationStartDate = existing?.authorizationStartDate;
    _authorizationEndDate = existing?.authorizationEndDate;
  }

  @override
  void dispose() {
    _eiCaseId.dispose();
    _municipality.dispose();
    _ifspAuthorizationNumber.dispose();
    _serviceType.dispose();
    _medicaidCin.dispose();
    _placeOfService.dispose();
    super.dispose();
  }

  Future<void> _pickDate({
    required bool isStart,
  }) async {
    final initial = isStart
        ? (_authorizationStartDate ?? DateTime.now())
        : (_authorizationEndDate ?? DateTime.now().add(const Duration(days: 180)));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _authorizationStartDate = picked;
      } else {
        _authorizationEndDate = picked;
      }
    });
  }

  Future<void> _save() async {
    final childId = _selectedChildId;
    if (childId == null || childId.isEmpty) {
      AppSnackBar.showError(context, 'Select a child.');
      return;
    }
    setState(() => _saving = true);
    try {
      final profile =
          await ref.read(eiBillingRepositoryProvider).upsertCaseProfile(
                childId: childId,
                eiCaseId:
                    _eiCaseId.text.trim().isEmpty ? null : _eiCaseId.text.trim(),
                municipality: _municipality.text.trim().isEmpty
                    ? null
                    : _municipality.text.trim(),
                ifspAuthorizationNumber: _ifspAuthorizationNumber.text.trim().isEmpty
                    ? null
                    : _ifspAuthorizationNumber.text.trim(),
                serviceType: _serviceType.text.trim().isEmpty
                    ? null
                    : _serviceType.text.trim(),
                medicaidCin: _medicaidCin.text.trim().isEmpty
                    ? null
                    : _medicaidCin.text.trim(),
                consentStatus: _consentStatus,
                authorizationStartDate: _authorizationStartDate,
                authorizationEndDate: _authorizationEndDate,
                placeOfService: _placeOfService.text.trim().isEmpty
                    ? null
                    : _placeOfService.text.trim(),
              );
      ref.invalidate(eiCaseBillingProfileProvider(childId));
      if (mounted) Navigator.pop(context, profile);
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          'Could not save case profile: ${AppSnackBar.messageFromError(e)}',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final children = ref.watch(agencyManagedChildrenProvider);

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
                    Expanded(
                      child: Text(
                        _selectedChildName != null
                            ? 'Case billing — $_selectedChildName'
                            : 'Case billing profile',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: AppTrustNotice.protectedInfo(dense: true),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      if (_selectedChildId == null)
                        children.when(
                          loading: () => const LinearProgressIndicator(),
                          error: (e, _) => Text('Caseload unavailable: $e'),
                          data: (rows) => DropdownButtonFormField<String>(
                            decoration:
                                const InputDecoration(labelText: 'Child *'),
                            initialValue: _selectedChildId,
                            items: rows
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c.id,
                                    child: Text('${c.firstName} ${c.lastName}'),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              final child =
                                  rows.firstWhere((c) => c.id == value);
                              setState(() {
                                _selectedChildId = value;
                                _selectedChildName =
                                    '${child.firstName} ${child.lastName}';
                              });
                            },
                          ),
                        ),
                      if (_selectedChildId == null) const SizedBox(height: 12),
                      TextField(
                        controller: _eiCaseId,
                        decoration: const InputDecoration(labelText: 'EI case ID'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _municipality,
                        decoration: const InputDecoration(labelText: 'Municipality'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _ifspAuthorizationNumber,
                        decoration: const InputDecoration(
                          labelText: 'IFSP authorization number',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _serviceType,
                        decoration: const InputDecoration(labelText: 'Service type'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _medicaidCin,
                        decoration: const InputDecoration(labelText: 'Medicaid CIN'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _placeOfService,
                        decoration: const InputDecoration(
                          labelText: 'Place of service',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Consent'),
                        initialValue: _consentStatus,
                        items: const [
                          DropdownMenuItem(
                            value: 'GRANTED',
                            child: Text('Granted'),
                          ),
                          DropdownMenuItem(
                            value: 'PENDING',
                            child: Text('Pending'),
                          ),
                          DropdownMenuItem(
                            value: 'DENIED',
                            child: Text('Denied'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _consentStatus = value);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Authorization start'),
                        subtitle: Text(
                          _authorizationStartDate != null
                              ? DateFormat.yMMMd()
                                  .format(_authorizationStartDate!)
                              : 'Not set',
                        ),
                        trailing: TextButton(
                          onPressed: () => _pickDate(isStart: true),
                          child: const Text('Pick'),
                        ),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Authorization end'),
                        subtitle: Text(
                          _authorizationEndDate != null
                              ? DateFormat.yMMMd().format(_authorizationEndDate!)
                              : 'Not set',
                        ),
                        trailing: TextButton(
                          onPressed: () => _pickDate(isStart: false),
                          child: const Text('Pick'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: GlossyButton(
                    title: 'Save case profile',
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

class _EiClearinghouseConfigSheet extends ConsumerStatefulWidget {
  const _EiClearinghouseConfigSheet({this.existing});

  final EiClearinghouseConfigModel? existing;

  @override
  ConsumerState<_EiClearinghouseConfigSheet> createState() =>
      _EiClearinghouseConfigSheetState();
}

class _EiClearinghouseConfigSheetState
    extends ConsumerState<_EiClearinghouseConfigSheet> {
  late final TextEditingController _name;
  late final TextEditingController _tradingPartnerId;
  late String _workflow;
  late bool _testMode;
  late bool _isActive;
  DateTime? _baaSignedAt;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _name = TextEditingController(text: existing?.name ?? '');
    _tradingPartnerId =
        TextEditingController(text: existing?.tradingPartnerId ?? '');
    _workflow = existing?.workflow ?? 'EI_HUB';
    _testMode = existing?.testMode ?? true;
    _isActive = existing?.isActive ?? false;
    _baaSignedAt = existing?.baaSignedAt;
  }

  @override
  void dispose() {
    _name.dispose();
    _tradingPartnerId.dispose();
    super.dispose();
  }

  Future<void> _pickBaaDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _baaSignedAt ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _baaSignedAt = picked);
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      AppSnackBar.showError(context, 'Name is required.');
      return;
    }
    setState(() => _saving = true);
    try {
      final config =
          await ref.read(eiBillingRepositoryProvider).upsertClearinghouseConfig(
                id: widget.existing?.id,
                name: _name.text.trim(),
                workflow: _workflow,
                tradingPartnerId: _tradingPartnerId.text.trim().isEmpty
                    ? null
                    : _tradingPartnerId.text.trim(),
                testMode: _testMode,
                isActive: _isActive,
                baaSignedAt: _baaSignedAt,
              );
      ref.invalidate(eiClearinghouseConfigsProvider);
      if (mounted) Navigator.pop(context, config);
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          'Could not save config: ${AppSnackBar.messageFromError(e)}',
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
      initialChildSize: 0.85,
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
                      widget.existing == null
                          ? 'Add clearinghouse config'
                          : 'Edit clearinghouse config',
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
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: AppTrustNotice(
                  dense: true,
                  message:
                      'Clearinghouse credentials are stored as references only. BAA must be signed before live transmission.',
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _name,
                        decoration: const InputDecoration(labelText: 'Name *'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Workflow'),
                        initialValue: _workflow,
                        items: eiClearinghouseWorkflows
                            .map(
                              (w) => DropdownMenuItem(
                                value: w,
                                child: Text(w),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) setState(() => _workflow = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _tradingPartnerId,
                        decoration: const InputDecoration(
                          labelText: 'Trading partner ID',
                        ),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('BAA signed date'),
                        subtitle: Text(
                          _baaSignedAt != null
                              ? DateFormat.yMMMd().format(_baaSignedAt!)
                              : 'Not set',
                        ),
                        trailing: TextButton(
                          onPressed: _pickBaaDate,
                          child: const Text('Pick date'),
                        ),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Test mode'),
                        value: _testMode,
                        onChanged: (value) => setState(() => _testMode = value),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Active'),
                        value: _isActive,
                        onChanged: (value) => setState(() => _isActive = value),
                      ),
                    ],
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: GlossyButton(
                    title: 'Save config',
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
