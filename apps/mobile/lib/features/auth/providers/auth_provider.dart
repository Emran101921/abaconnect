import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/consent_gate_provider.dart';
import '../../../shared/models/user_role.dart';
import '../data/auth_repository.dart';

class AuthNotifier extends StateNotifier<AsyncValue<AuthSession?>> {
  AuthNotifier(this._repository, this._ref) : super(const AsyncValue.loading()) {
    _restore();
  }

  final AuthRepository _repository;
  final Ref _ref;

  Future<void> _restore() async {
    try {
      final session = await _repository.loadSession();
      state = AsyncValue.data(session);
      await refreshOnboardingGates(_ref, session?.user.role);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<LoginResponse> login({
    required String email,
    required String password,
    UserRole role = UserRole.parent,
  }) async {
    state = const AsyncValue.loading();
    try {
      final result = await _repository.login(email: email, password: password);
      if (result.requiresMfa) {
        state = const AsyncValue.data(null);
        return result;
      }
      final session = await _repository.loadSession();
      state = AsyncValue.data(session);
      await refreshOnboardingGates(_ref, session?.user.role);
      return result;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> completeMfaLogin({
    required String mfaChallengeToken,
    required String code,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repository.completeMfaLogin(
        mfaChallengeToken: mfaChallengeToken,
        code: code,
      );
      final session = await _repository.loadSession();
      state = AsyncValue.data(session);
      await refreshOnboardingGates(_ref, session?.user.role);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repository.register(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
      );
      final session = await _repository.loadSession();
      state = AsyncValue.data(session);
      await refreshOnboardingGates(_ref, session?.user.role);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AsyncValue.data(null);
    _ref.read(hipaaConsentGrantedProvider.notifier).state = false;
    _ref.read(mfaEnabledProvider.notifier).state = false;
  }
}
