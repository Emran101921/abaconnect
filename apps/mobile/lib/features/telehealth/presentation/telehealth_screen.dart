import 'package:flutter/material.dart';

import '../../../shared/widgets/app_scaffold.dart';

class TelehealthScreen extends StatelessWidget {
  const TelehealthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Telehealth',
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.videocam,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Virtual Session',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text('Join your scheduled telehealth appointment.'),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.video_call),
                label: const Text('Join Session'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
