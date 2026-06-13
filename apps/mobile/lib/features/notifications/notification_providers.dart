import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';

final unreadNotificationsProvider = FutureProvider.autoDispose<int>((ref) {
  return ref.watch(platformRepositoryProvider).fetchUnreadNotificationCount();
});
