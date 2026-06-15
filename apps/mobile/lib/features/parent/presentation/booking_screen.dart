import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/app_dashboard_card.dart';
import '../../../shared/widgets/app_healthcare_illustration.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_section_header.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../data/parent_booking_repository.dart';
import 'parent_dashboard_providers.dart';

class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({super.key});

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  List<ChildModel> _children = [];
  List<TherapistModel> _therapists = [];
  String? _childId;
  String? _therapistId;
  String _therapyType = 'ABA';
  String _locationType = 'IN_HOME';
  DateTime _start = DateTime.now().add(const Duration(days: 1));
  bool _recurring = false;
  int _recurringWeeks = 4;
  bool _loading = true;
  bool _submitting = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    final repo = ref.read(parentBookingRepositoryProvider);
    try {
      final children = await repo.fetchChildren();
      final therapists = await repo.fetchTherapists(therapyType: _therapyType);
      setState(() {
        _children = children;
        _therapists = therapists;
        _childId = children.isNotEmpty ? children.first.id : null;
        _therapistId = therapists.isNotEmpty ? therapists.first.id : null;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _loadError = AppSnackBar.messageFromError(e);
      });
    }
  }

  Future<void> _book() async {
    if (_childId == null || _therapistId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select child and therapist')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final end = _start.add(const Duration(hours: 1));
      final repo = ref.read(parentBookingRepositoryProvider);
      if (_recurring) {
        final count = await repo.bookRecurringAppointments(
          childId: _childId!,
          therapistId: _therapistId!,
          therapyType: _therapyType,
          start: _start,
          end: end,
          weeks: _recurringWeeks,
          locationType: _locationType,
        );
        ref.invalidate(parentAppointmentsProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Booked $count weekly sessions')),
          );
          context.pop();
        }
      } else {
        await repo.bookAppointment(
          childId: _childId!,
          therapistId: _therapistId!,
          therapyType: _therapyType,
          start: _start,
          end: end,
          locationType: _locationType,
        );
        ref.invalidate(parentAppointmentsProvider);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Appointment booked')));
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Booking failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  ChildModel? get _selectedChild {
    if (_childId == null) return null;
    for (final child in _children) {
      if (child.id == _childId) return child;
    }
    return null;
  }

  bool _isSelfPayChild(ChildModel? child) {
    final type = child?.insuranceType;
    return type == null || type == 'Self-pay';
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      initialDate: _start,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_start),
    );
    if (time == null) return;
    setState(() {
      _start = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AppScaffold(
        title: 'Book Session',
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null) {
      return AppScaffold(
        title: 'Book Session',
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Could not load booking options',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _loadError!,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                GlossyButton(
                  title: 'Retry',
                  icon: Icons.refresh_rounded,
                  variant: GlossyButtonVariant.neutral,
                  onPressed: _load,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AppScaffold(
      title: 'Book Session',
      body: AppContentContainer(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppSectionHeader(
                title: 'Schedule a session',
                subtitle: 'Book therapy with a matched provider',
              ),
              const SizedBox(height: 12),
              AppDashboardCard(
                elevated: false,
                child: const AppIllustrationRow(
                  type: AppIllustrationType.scheduling,
                  title: 'Flexible scheduling',
                  subtitle: 'In-home, clinic, school, or telehealth',
                ),
              ),
              const SizedBox(height: 16),
              AppDashboardCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownMenu<String>(
                      label: const Text('Child'),
                      initialSelection: _childId,
                      dropdownMenuEntries: _children
                          .map(
                            (c) => DropdownMenuEntry(
                              value: c.id,
                              label:
                                  '${c.displayName} · ${c.insuranceType ?? 'Self-pay'}',
                            ),
                          )
                          .toList(),
                      onSelected: (v) => setState(() => _childId = v),
                    ),
                    if (_selectedChild != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Chip(
                            avatar: Icon(
                              _isSelfPayChild(_selectedChild)
                                  ? Icons.payments_outlined
                                  : Icons.health_and_safety_outlined,
                              size: 18,
                            ),
                            label: Text(
                              _selectedChild!.insuranceType ?? 'Self-pay',
                            ),
                          ),
                        ],
                      ),
                      if (_isSelfPayChild(_selectedChild)) ...[
                        const SizedBox(height: 8),
                        Card(
                          color: Theme.of(context)
                              .colorScheme
                              .primaryContainer
                              .withValues(alpha: 0.35),
                          child: const ListTile(
                            leading: Icon(Icons.info_outline),
                            title: Text('Self-pay payment'),
                            subtitle: Text(
                              'After each completed session, you will receive a '
                              'payment request in Payments. Pay securely via Stripe '
                              'before the next visit when possible.',
                            ),
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 16),
                    DropdownMenu<String>(
                      label: const Text('Therapy type'),
                      initialSelection: _therapyType,
                      dropdownMenuEntries: const [
                        DropdownMenuEntry(value: 'ABA', label: 'ABA Therapy'),
                        DropdownMenuEntry(
                          value: 'SPEECH',
                          label: 'Speech Therapy',
                        ),
                        DropdownMenuEntry(value: 'OCCUPATIONAL', label: 'OT'),
                        DropdownMenuEntry(value: 'PHYSICAL', label: 'PT'),
                      ],
                      onSelected: (v) async {
                        if (v == null) return;
                        setState(() {
                          _therapyType = v;
                          _loading = true;
                        });
                        final therapists = await ref
                            .read(parentBookingRepositoryProvider)
                            .fetchTherapists(therapyType: v);
                        setState(() {
                          _therapists = therapists;
                          _therapistId = therapists.isNotEmpty
                              ? therapists.first.id
                              : null;
                          _loading = false;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownMenu<String>(
                      label: const Text('Therapist'),
                      initialSelection: _therapistId,
                      dropdownMenuEntries: _therapists
                          .map(
                            (t) => DropdownMenuEntry(
                              value: t.id,
                              label:
                                  '${t.displayName} (${t.rating.toStringAsFixed(1)}★)',
                            ),
                          )
                          .toList(),
                      onSelected: (v) => setState(() => _therapistId = v),
                    ),
                    const SizedBox(height: 16),
                    DropdownMenu<String>(
                      label: const Text('Session location'),
                      initialSelection: _locationType,
                      dropdownMenuEntries: const [
                        DropdownMenuEntry(value: 'IN_HOME', label: 'In home'),
                        DropdownMenuEntry(value: 'CLINIC', label: 'Clinic'),
                        DropdownMenuEntry(value: 'SCHOOL', label: 'School'),
                        DropdownMenuEntry(
                          value: 'TELEHEALTH',
                          label: 'Telehealth',
                        ),
                        DropdownMenuEntry(
                          value: 'COMMUNITY',
                          label: 'Community',
                        ),
                      ],
                      onSelected: (v) {
                        if (v != null) setState(() => _locationType = v);
                      },
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Date & Time'),
                      subtitle: Text(_start.toLocal().toString()),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: _pickDateTime,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Weekly recurring'),
                      subtitle: const Text('Book the same slot each week'),
                      value: _recurring,
                      onChanged: (v) => setState(() => _recurring = v),
                    ),
                    if (_recurring)
                      DropdownMenu<int>(
                        label: const Text('Number of weeks'),
                        initialSelection: _recurringWeeks,
                        dropdownMenuEntries: List.generate(
                          11,
                          (i) => DropdownMenuEntry(
                            value: i + 2,
                            label: '${i + 2} weeks',
                          ),
                        ),
                        onSelected: (v) {
                          if (v != null) setState(() => _recurringWeeks = v);
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              GlossyButton(
                title: 'Confirm booking',
                icon: Icons.event_available,
                variant: GlossyButtonVariant.greenTeal,
                loading: _submitting,
                onPressed: _book,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
