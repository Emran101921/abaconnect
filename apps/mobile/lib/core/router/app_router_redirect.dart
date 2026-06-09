import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../shared/models/user_role.dart';
import 'app_router.dart';

String? resolveAuthRedirect({
  required AsyncValue<AuthSession?> auth,
  required String matchedLocation,
}) {
  if (auth.isLoading) {
    final waitingRoutes = <String>{
      AppRoutes.splash,
      AppRoutes.login,
      AppRoutes.register,
      AppRoutes.forgotPassword,
    };
    if (waitingRoutes.contains(matchedLocation) ||
        matchedLocation.startsWith(AppRoutes.resetPassword)) {
      return null;
    }
    return AppRoutes.splash;
  }

  final session = auth.valueOrNull;
  final isResetPassword = matchedLocation.startsWith(AppRoutes.resetPassword);
  final isPublic =
      matchedLocation == AppRoutes.splash ||
      matchedLocation == AppRoutes.login ||
      matchedLocation == AppRoutes.register ||
      matchedLocation == AppRoutes.forgotPassword ||
      isResetPassword;

  if (session == null) {
    if (isPublic) {
      return null;
    }
    return AppRoutes.login;
  }

  final home = session.user.role.homeRoute;

  if (matchedLocation == AppRoutes.login ||
      matchedLocation == AppRoutes.register ||
      matchedLocation == AppRoutes.forgotPassword) {
    return home;
  }

  if (matchedLocation.startsWith('/parent') &&
      session.user.role != UserRole.parent) {
    return home;
  }
  if (matchedLocation.startsWith('/therapist') &&
      session.user.role != UserRole.therapist) {
    return home;
  }
  if (matchedLocation.startsWith('/agency') &&
      session.user.role != UserRole.agency) {
    return home;
  }
  if (matchedLocation.startsWith('/admin') &&
      session.user.role != UserRole.admin) {
    return home;
  }

  return null;
}
