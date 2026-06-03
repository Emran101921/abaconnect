import 'package:flutter/material.dart';

import '../../../shared/widgets/app_scaffold.dart';

class MatchResultsScreen extends StatelessWidget {
  const MatchResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Matched Therapists',
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 3,
        separatorBuilder: (context, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(child: Text('T${index + 1}')),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dr. Therapist ${index + 1}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text('ABA Specialist · ${95 - index * 3}% match'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () {},
                    child: const Text('Request Match'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
