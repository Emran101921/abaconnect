import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/user_role.dart';
import '../providers/app_providers.dart';

/// Whether the signed-in user has granted HIPAA privacy consent.
/// Defaults to false so users cannot slip past the gate before status loads.
final hipaaConsentGrantedProvider = StateProvider<bool>((ref) => false);

/// Whether the signed-in user has enrolled in MFA.
/// Defaults to false so users cannot slip past the gate before status loads.
final mfaEnabledProvider = StateProvider<bool>((ref) => false);

/// Roles that must complete HIPAA consent + MFA enrollment before using the app.
bool roleRequiresOnboarding(UserRole role) {
  return role == UserRole.parent ||
      role == UserRole.therapist ||
      role == UserRole.agency;
}

/// Back-compat alias — consent is part of the broader onboarding requirement.
bool roleRequiresHipaaConsent(UserRole role) => roleRequiresOnboarding(role);

/// Refreshes the onboarding gates (HIPAA consent + MFA) for the given [role].
///
/// The role is passed in explicitly (rather than read from [authStateProvider])
/// because this is invoked from inside the AuthNotifier — reading the auth
/// provider from its own Ref would trip Riverpod's "a provider cannot depend on
/// itself" assertion.
Future<void> refreshOnboardingGates(Ref ref, UserRole? role) async {
  if (role == null || !roleRequiresOnboarding(role)) {
    ref.read(hipaaConsentGrantedProvider.notifier).state = true;
    ref.read(mfaEnabledProvider.notifier).state = true;
    return;
  }
  try {
    final me = await ref.read(authRepositoryProvider).fetchMe();
    ref.read(hipaaConsentGrantedProvider.notifier).state =
        me.hipaaConsentGranted;
    ref.read(mfaEnabledProvider.notifier).state = me.mfaEnabled;
  } catch (_) {
    // If we cannot confirm onboarding status, keep the gates closed so the
    // user is routed through consent/MFA rather than slipping into the app.
    ref.read(hipaaConsentGrantedProvider.notifier).state = false;
    ref.read(mfaEnabledProvider.notifier).state = false;
  }
}
