import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/user_role.dart';
import '../providers/app_providers.dart';

/// Whether the signed-in parent/therapist has granted HIPAA privacy consent.
final hipaaConsentGrantedProvider = StateProvider<bool>((ref) => true);

bool roleRequiresHipaaConsent(UserRole role) {
  return role == UserRole.parent || role == UserRole.therapist;
}

/// Refreshes the HIPAA consent gate for the given [role].
///
/// The role is passed in explicitly (rather than read from [authStateProvider])
/// because this is invoked from inside the AuthNotifier — reading the auth
/// provider from its own Ref would trip Riverpod's "a provider cannot depend on
/// itself" assertion.
Future<void> refreshHipaaConsentGate(Ref ref, UserRole? role) async {
  if (role == null || !roleRequiresHipaaConsent(role)) {
    ref.read(hipaaConsentGrantedProvider.notifier).state = true;
    return;
  }
  final consents = await ref.read(platformRepositoryProvider).fetchConsents();
  final granted = consents.any(
    (c) => c.consentType == 'HIPAA_PRIVACY' && c.granted,
  );
  ref.read(hipaaConsentGrantedProvider.notifier).state = granted;
}
