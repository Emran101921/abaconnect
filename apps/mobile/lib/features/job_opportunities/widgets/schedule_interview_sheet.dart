import 'package:flutter/material.dart';

class ScheduleInterviewResult {
  const ScheduleInterviewResult({
    required this.scheduledAt,
    required this.durationMinutes,
    required this.recordingRequested,
    required this.agencyRecordingConsent,
    this.notes,
  });

  final DateTime scheduledAt;
  final int durationMinutes;
  final bool recordingRequested;
  final bool agencyRecordingConsent;
  final String? notes;
}

Future<ScheduleInterviewResult?> showScheduleInterviewSheet(
  BuildContext context, {
  required String therapistName,
}) {
  return showModalBottomSheet<ScheduleInterviewResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _ScheduleInterviewSheet(therapistName: therapistName),
  );
}

class _ScheduleInterviewSheet extends StatefulWidget {
  const _ScheduleInterviewSheet({required this.therapistName});

  final String therapistName;

  @override
  State<_ScheduleInterviewSheet> createState() =>
      _ScheduleInterviewSheetState();
}

class _ScheduleInterviewSheetState extends State<_ScheduleInterviewSheet> {
  DateTime _scheduledAt = DateTime.now().add(const Duration(days: 1));
  int _durationMinutes = 30;
  bool _recordingRequested = false;
  bool _agencyRecordingConsent = false;
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      initialDate: _scheduledAt,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt),
    );
    if (time == null || !mounted) return;
    setState(() {
      _scheduledAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  void _submit() {
    if (_scheduledAt.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a future date and time')),
      );
      return;
    }
    Navigator.pop(
      context,
      ScheduleInterviewResult(
        scheduledAt: _scheduledAt,
        durationMinutes: _durationMinutes,
        recordingRequested: _recordingRequested,
        agencyRecordingConsent: _recordingRequested && _agencyRecordingConsent,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.paddingOf(context).bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Schedule video interview',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text('With ${widget.therapistName}'),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Date & time'),
            subtitle: Text(_scheduledAt.toLocal().toString().split('.').first),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: _pickDateTime,
          ),
          DropdownButtonFormField<int>(
            value: _durationMinutes,
            decoration: const InputDecoration(labelText: 'Duration'),
            items: const [30, 45, 60]
                .map((m) => DropdownMenuItem(value: m, child: Text('$m minutes')))
                .toList(),
            onChanged: (v) => setState(() => _durationMinutes = v ?? 30),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Record interview'),
            subtitle: const Text(
              'Both you and the therapist must consent before recording starts',
            ),
            value: _recordingRequested,
            onChanged: (v) => setState(() {
              _recordingRequested = v;
              if (!v) _agencyRecordingConsent = false;
            }),
          ),
          if (_recordingRequested)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('I consent to recording this interview'),
              value: _agencyRecordingConsent,
              onChanged: (v) =>
                  setState(() => _agencyRecordingConsent = v ?? false),
            ),
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Notes for therapist (optional)',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _submit,
            child: const Text('Schedule interview'),
          ),
        ],
      ),
    );
  }
}
