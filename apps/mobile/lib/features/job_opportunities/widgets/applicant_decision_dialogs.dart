import 'package:flutter/material.dart';

Future<String?> showInterviewNotesDialog(
  BuildContext context, {
  String? initialNotes,
  String title = 'Interview notes',
}) async {
  final controller = TextEditingController(text: initialNotes ?? '');
  final notes = await showDialog<String?>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(
          labelText: 'Notes for your team',
          hintText: 'Impressions, follow-ups, credential requests…',
          border: OutlineInputBorder(),
        ),
        maxLines: 4,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  controller.dispose();
  return notes;
}

Future<String?> showApplicantDecisionNoteDialog(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String hint = 'Optional note to the therapist',
}) async {
  final controller = TextEditingController();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: hint,
          border: const OutlineInputBorder(),
        ),
        maxLines: 3,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  final note = controller.text.trim();
  controller.dispose();
  if (confirmed != true) return null;
  return note;
}

bool applicationStatusIsTerminal(String status) {
  return status == 'REJECTED' ||
      status == 'WITHDRAWN' ||
      status == 'HIRED_CONTRACTED';
}

class SendJobOfferFormResult {
  const SendJobOfferFormResult({
    this.compensationRate,
    this.startDate,
    this.message,
  });

  final String? compensationRate;
  final DateTime? startDate;
  final String? message;
}

Future<SendJobOfferFormResult?> showSendJobOfferDialog(
  BuildContext context, {
  String? suggestedCompensation,
}) async {
  final compensationController = TextEditingController(
    text: suggestedCompensation ?? '',
  );
  final messageController = TextEditingController();
  DateTime? startDate;

  void applyTemplate(String compensation, String message) {
    compensationController.text = compensation;
    messageController.text = message;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Send job offer'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quick templates',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    label: const Text('Hourly'),
                    onPressed: () {
                      setState(() {
                        applyTemplate(
                          suggestedCompensation ?? '\$65/hr',
                          'We would like to offer you this role at the posted rate. '
                              'Please confirm your availability for onboarding.',
                        );
                      });
                    },
                  ),
                  ActionChip(
                    label: const Text('Full-time'),
                    onPressed: () {
                      setState(() {
                        applyTemplate(
                          suggestedCompensation ?? '\$75,000/year',
                          'We are pleased to extend a full-time offer with benefits. '
                              'Our team will share the contract packet after you accept.',
                        );
                      });
                    },
                  ),
                  ActionChip(
                    label: const Text('Per diem'),
                    onPressed: () {
                      setState(() {
                        applyTemplate(
                          suggestedCompensation ?? '\$55/session',
                          'Per diem contractor offer — flexible caseload based on agency needs.',
                        );
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: compensationController,
                decoration: const InputDecoration(
                  labelText: 'Compensation',
                  hintText: 'e.g. \$65/hr or \$52,000/year',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  startDate == null
                      ? 'Preferred start date (optional)'
                      : 'Start: ${MaterialLocalizations.of(context).formatMediumDate(startDate!)}',
                ),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 14)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() => startDate = picked);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: messageController,
                decoration: const InputDecoration(
                  labelText: 'Message to therapist',
                  hintText: 'Schedule, benefits, next steps…',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Send offer'),
          ),
        ],
      ),
    ),
  );

  final compensation = compensationController.text.trim();
  final message = messageController.text.trim();
  compensationController.dispose();
  messageController.dispose();
  if (confirmed != true) return null;

  return SendJobOfferFormResult(
    compensationRate: compensation.isEmpty ? null : compensation,
    startDate: startDate,
    message: message.isEmpty ? null : message,
  );
}
