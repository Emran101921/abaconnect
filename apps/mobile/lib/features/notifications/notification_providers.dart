import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';

final unreadNotificationsProvider = FutureProvider<int>((ref) {
  return ref.watch(platformRepositoryProvider).fetchUnreadNotificationCount();
});
