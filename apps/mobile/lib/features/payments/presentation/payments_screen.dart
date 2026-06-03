import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/app_scaffold.dart';

class PaymentsScreen extends StatelessWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(symbol: '\$');

    return AppScaffold(
      title: 'Payments',
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 3,
        separatorBuilder: (context, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return Card(
            child: ListTile(
              title: Text('Invoice #${1000 + index}'),
              subtitle: Text('Session on May ${10 + index}, 2026'),
              trailing: Text(
                formatter.format(150.0 + index * 25),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              onTap: () {},
            ),
          );
        },
      ),
    );
  }
}
