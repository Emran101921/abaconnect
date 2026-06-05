import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';

final unreadMessageThreadsProvider = FutureProvider<int>((ref) {
  return ref.watch(messagingRepositoryProvider).fetchUnreadThreadCount();
});
