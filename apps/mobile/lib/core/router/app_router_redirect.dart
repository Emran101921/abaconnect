import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../shared/models/user_role.dart';
import 'app_router.dart';
import 'onboarding_navigation.dart';

String? resolveAuthRedirect({
  required AsyncValue<AuthSession?> auth,
  required String matchedLocation,
  required bool hipaaConsentGranted,
  required bool mfaEnabled,
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
  final onboardingRoute = resolveOnboardingRoute(
    role: session.user.role,
    hipaaConsentGranted: hipaaConsentGranted,
    mfaEnabled: mfaEnabled,
  );

  if (matchedLocation == AppRoutes.login ||
      matchedLocation == AppRoutes.register ||
      matchedLocation == AppRoutes.forgotPassword) {
    return onboardingRoute ?? home;
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

  final privacyOnboardingRoutes = <String>{
    AppRoutes.consent,
    AppRoutes.signupPrivacyNotice,
    AppRoutes.privacyNoticeOfPractices,
    AppRoutes.privacyPolicy,
  };
  final isPrivacyOnboardingRoute = privacyOnboardingRoutes.contains(
    matchedLocation,
  );

  // Mandatory onboarding: parents, therapists, and agency admins must
  // acknowledge the Notice of Privacy Practices and enroll in MFA first.
  if (onboardingRoute != null) {
    final onConsent = matchedLocation == AppRoutes.consent;
    final onSecurity = matchedLocation == AppRoutes.security;
    if (onboardingRoute == AppRoutes.consent &&
        !onConsent &&
        !isPrivacyOnboardingRoute) {
      return AppRoutes.consent;
    }
    if (onboardingRoute == AppRoutes.security &&
        !onSecurity &&
        !onConsent &&
        !isPrivacyOnboardingRoute) {
      return AppRoutes.security;
    }
  }

  if (matchedLocation == AppRoutes.consent ||
      matchedLocation == AppRoutes.security ||
      isPrivacyOnboardingRoute ||
      matchedLocation == AppRoutes.settingsPrivacy ||
      matchedLocation.startsWith('${AppRoutes.settingsPrivacy}/')) {
    return null;
  }

  if (matchedLocation == AppRoutes.messages ||
      matchedLocation.startsWith('${AppRoutes.messages}/')) {
    if (session.user.role != UserRole.parent &&
        session.user.role != UserRole.therapist) {
      return home;
    }
  }

  if (matchedLocation == AppRoutes.documents &&
      session.user.role != UserRole.parent &&
      session.user.role != UserRole.therapist) {
    return home;
  }

  return null;
}
