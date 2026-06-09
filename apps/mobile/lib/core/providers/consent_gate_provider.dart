import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/user_role.dart';
import '../providers/app_providers.dart';

/// Whether the signed-in parent/therapist has granted HIPAA privacy consent.
final hipaaConsentGrantedProvider = StateProvider<bool>((ref) => true);

bool roleRequiresHipaaConsent(UserRole role) {
  return role == UserRole.parent || role == UserRole.therapist;
}

Future<void> refreshHipaaConsentGate(Ref ref) async {
  final auth = ref.read(authStateProvider).valueOrNull;
  if (auth == null || !roleRequiresHipaaConsent(auth.user.role)) {
    ref.read(hipaaConsentGrantedProvider.notifier).state = true;
    return;
  }
  final consents = await ref.read(platformRepositoryProvider).fetchConsents();
  final granted = consents.any(
    (c) => c.consentType == 'HIPAA_PRIVACY' && c.granted,
  );
  ref.read(hipaaConsentGrantedProvider.notifier).state = granted;
}
