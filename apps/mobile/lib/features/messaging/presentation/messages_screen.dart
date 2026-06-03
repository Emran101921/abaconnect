import 'package:flutter/material.dart';

import '../../../shared/widgets/app_scaffold.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Messages',
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 4,
        separatorBuilder: (context, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          return ListTile(
            leading: CircleAvatar(child: Text('U$index')),
            title: Text('Conversation ${index + 1}'),
            subtitle: const Text('Latest message preview...'),
            trailing: const Text('2h'),
            onTap: () {},
          );
        },
      ),
    );
  }
}
