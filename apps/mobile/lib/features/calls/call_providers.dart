import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import 'data/call_models.dart';
import 'data/calls_repository.dart';

final callsRepositoryProvider = Provider<CallsRepository>((ref) {
  return CallsRepository(ref.watch(graphqlClientProvider));
});

final callHistoryProvider =
    FutureProvider.family<List<CallSessionModel>, CallHistoryParams>((
  ref,
  params,
) async {
  final repo = ref.watch(callsRepositoryProvider);
  return repo.fetchCallHistory(
    childId: params.childId,
    userId: params.userId,
    status: params.status,
    callType: params.callType,
    limit: params.limit,
  );
});

final incomingRingingCallProvider = FutureProvider<CallSessionModel?>((
  ref,
) async {
  final repo = ref.watch(callsRepositoryProvider);
  return repo.fetchIncomingRingingCall();
});

final callSessionProvider = FutureProvider.family<CallSessionModel?, String>((
  ref,
  callSessionId,
) async {
  final repo = ref.watch(callsRepositoryProvider);
  return repo.fetchCallSession(callSessionId);
});

final agencyCallAuditProvider =
    FutureProvider.family<List<CallAuditLogModel>, AgencyAuditParams>((
  ref,
  params,
) async {
  final repo = ref.watch(callsRepositoryProvider);
  return repo.fetchAgencyAuditLogs(
    childId: params.childId,
    userId: params.userId,
    role: params.role,
    status: params.status,
    callType: params.callType,
    callSessionId: params.callSessionId,
    limit: params.limit,
  );
});

class CallHistoryParams {
  const CallHistoryParams({
    this.childId,
    this.userId,
    this.status,
    this.callType,
    this.limit,
  });

  final String? childId;
  final String? userId;
  final String? status;
  final String? callType;
  final int? limit;

  @override
  bool operator ==(Object other) =>
      other is CallHistoryParams &&
      other.childId == childId &&
      other.userId == userId &&
      other.status == status &&
      other.callType == callType &&
      other.limit == limit;

  @override
  int get hashCode => Object.hash(childId, userId, status, callType, limit);
}

class AgencyAuditParams {
  const AgencyAuditParams({
    this.childId,
    this.userId,
    this.role,
    this.status,
    this.callType,
    this.callSessionId,
    this.limit,
  });

  final String? childId;
  final String? userId;
  final String? role;
  final String? status;
  final String? callType;
  final String? callSessionId;
  final int? limit;

  @override
  bool operator ==(Object other) =>
      other is AgencyAuditParams &&
      other.childId == childId &&
      other.userId == userId &&
      other.role == role &&
      other.status == status &&
      other.callType == callType &&
      other.callSessionId == callSessionId &&
      other.limit == limit;

  @override
  int get hashCode => Object.hash(
        childId,
        userId,
        role,
        status,
        callType,
        callSessionId,
        limit,
      );
}
