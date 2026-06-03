import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../data/parent_booking_repository.dart';
import 'parent_home_screen.dart';

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
  DateTime _start = DateTime.now().add(const Duration(days: 1));
  bool _recurring = false;
  int _recurringWeeks = 4;
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
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
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Load failed: $e')),
        );
      }
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
        );
        ref.invalidate(parentAppointmentsProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Appointment booked')),
          );
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Booking failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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

    return AppScaffold(
      title: 'Book Session',
      body: Padding(
        padding: const EdgeInsets.all(16),
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
                      label: c.displayName,
                    ),
                  )
                  .toList(),
              onSelected: (v) => setState(() => _childId = v),
            ),
            const SizedBox(height: 16),
            DropdownMenu<String>(
              label: const Text('Therapy type'),
              initialSelection: _therapyType,
              dropdownMenuEntries: const [
                DropdownMenuEntry(value: 'ABA', label: 'ABA Therapy'),
                DropdownMenuEntry(value: 'SPEECH', label: 'Speech Therapy'),
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
                  _therapistId =
                      therapists.isNotEmpty ? therapists.first.id : null;
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
            const Spacer(),
            FilledButton(
              onPressed: _submitting ? null : _book,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Confirm Booking'),
            ),
          ],
        ),
      ),
    );
  }
}
