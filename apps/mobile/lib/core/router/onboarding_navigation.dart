import '../../shared/models/user_role.dart';
import '../providers/consent_gate_provider.dart';
import 'app_router.dart';

/// Resolves the first screen a signed-in user must visit before using the app.
///
/// Parents, therapists, and agency admins must grant HIPAA consent and enroll
/// in MFA immediately after sign-up or sign-in.
String? resolveOnboardingRoute({
  required UserRole role,
  required bool hipaaConsentGranted,
  required bool mfaEnabled,
  bool providerPhiAccessApproved = true,
  bool agencyOnboardingComplete = true,
}) {
  if (!roleRequiresOnboarding(role)) {
    return null;
  }
  if (!hipaaConsentGranted) {
    return AppRoutes.consent;
  }
  if (!mfaEnabled) {
    return AppRoutes.security;
  }
  if (role == UserRole.agency && !agencyOnboardingComplete) {
    return AppRoutes.agencyOnboarding;
  }
  if (role == UserRole.therapist && !providerPhiAccessApproved) {
    return AppRoutes.providerOnboarding;
  }
  return null;
}
