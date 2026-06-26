import 'package:flutter/material.dart';

class ScheduleFirstSessionResult {
  const ScheduleFirstSessionResult({
    required this.scheduledStart,
    this.durationMinutes = 60,
    this.notes,
  });

  final DateTime scheduledStart;
  final int durationMinutes;
  final String? notes;
}

Future<ScheduleFirstSessionResult?> showScheduleFirstSessionSheet(
  BuildContext context, {
  required String therapistName,
}) {
  final notesController = TextEditingController();
  DateTime? start;
  var duration = 60;

  return showDialog<ScheduleFirstSessionResult>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Schedule first session'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Assign $therapistName to the child on this posting and create '
                'a confirmed appointment.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  start == null
                      ? 'Pick date & time'
                      : start!.toLocal().toString().split('.').first,
                ),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 3)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 120)),
                  );
                  if (date == null || !context.mounted) return;
                  final time = await showTimePicker(
                    context: context,
                    initialTime: const TimeOfDay(hour: 10, minute: 0),
                  );
                  if (time == null) return;
                  setState(() {
                    start = DateTime(
                      date.year,
                      date.month,
                      date.day,
                      time.hour,
                      time.minute,
                    );
                  });
                },
              ),
              DropdownButtonFormField<int>(
                initialValue: duration,
                decoration: const InputDecoration(
                  labelText: 'Duration',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 30, child: Text('30 minutes')),
                  DropdownMenuItem(value: 45, child: Text('45 minutes')),
                  DropdownMenuItem(value: 60, child: Text('60 minutes')),
                  DropdownMenuItem(value: 90, child: Text('90 minutes')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => duration = value);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Session notes (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Skip for now'),
          ),
          FilledButton(
            onPressed: start == null
                ? null
                : () => Navigator.pop(
                      context,
                      ScheduleFirstSessionResult(
                        scheduledStart: start!,
                        durationMinutes: duration,
                        notes: notesController.text.trim().isEmpty
                            ? null
                            : notesController.text.trim(),
                      ),
                    ),
            child: const Text('Schedule session'),
          ),
        ],
      ),
    ),
  );
}
