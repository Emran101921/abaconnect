import '../../../core/network/graphql_client.dart';

import 'call_models.dart';

class CallsRepository {
  CallsRepository(this._graphql);

  final GraphqlClient _graphql;

  static const _initiateCall = r'''
    mutation InitiateCall($input: InitiateCallInput!) {
      initiateCall(input: $input) {
        id
        callType
        status
        childId
        initiatedByUserId
        initiatedByName
        recipientUserId
        recipientName
        providerName
        joinUrl
        token
        tokenExpiresAt
        createdAt
      }
    }
  ''';

  static const _acceptCall = r'''
    mutation AcceptCall($callSessionId: ID!) {
      acceptCall(callSessionId: $callSessionId) {
        id
        callType
        status
        initiatedByUserId
        initiatedByName
        recipientUserId
        recipientName
        providerName
        joinUrl
        token
        tokenExpiresAt
        startedAt
        createdAt
      }
    }
  ''';

  static const _declineCall = '''
    mutation DeclineCall(\$callSessionId: ID!, \$reason: String) {
      declineCall(callSessionId: \$callSessionId, reason: \$reason) {
        id
        callType
        status
        childId
        initiatedByUserId
        initiatedByName
        recipientUserId
        recipientName
        providerName
        startedAt
        endedAt
        durationSeconds
        createdAt
      }
    }
  ''';

  static const _endCall = '''
    mutation EndCall(\$callSessionId: ID!) {
      endCall(callSessionId: \$callSessionId) {
        id
        callType
        status
        childId
        initiatedByUserId
        initiatedByName
        recipientUserId
        recipientName
        providerName
        startedAt
        endedAt
        durationSeconds
        createdAt
      }
    }
  ''';

  static const _cancelCall = '''
    mutation CancelCall(\$callSessionId: ID!) {
      cancelCall(callSessionId: \$callSessionId) {
        id
        callType
        status
        childId
        initiatedByUserId
        initiatedByName
        recipientUserId
        recipientName
        providerName
        startedAt
        endedAt
        durationSeconds
        createdAt
      }
    }
  ''';

  static const _callHistory = r'''
    query CallHistory($filter: CallHistoryFilterInput) {
      callHistory(filter: $filter) {
        id
        callType
        status
        childId
        initiatedByUserId
        initiatedByName
        recipientUserId
        recipientName
        startedAt
        endedAt
        durationSeconds
        createdAt
        participants {
          userId
          displayName
          role
          joinStatus
        }
      }
    }
  ''';

  static const _incomingRinging = r'''
    query IncomingRingingCall {
      incomingRingingCall {
        id
        callType
        status
        initiatedByUserId
        initiatedByName
        childId
        createdAt
      }
    }
  ''';

  static const _callSession = r'''
    query CallSession($callSessionId: ID!) {
      callSession(callSessionId: $callSessionId) {
        id
        callType
        status
        childId
        initiatedByUserId
        initiatedByName
        recipientUserId
        recipientName
        providerName
        joinUrl
        token
        tokenExpiresAt
        startedAt
        createdAt
      }
    }
  ''';

  static const _agencyAudit = r'''
    query AgencyCallAuditLogs($filter: AgencyCallAuditFilterInput) {
      agencyCallAuditLogs(filter: $filter) {
        id
        callSessionId
        childId
        actorUserId
        actorRole
        targetUserId
        targetRole
        eventType
        callType
        callStatus
        reason
        createdAt
      }
    }
  ''';

  Future<CallSessionModel> initiateCall({
    required String recipientUserId,
    required CallType callType,
    String? childId,
  }) async {
    final result = await _graphql.query(
      _initiateCall,
      variables: {
        'input': {
          'recipientUserId': recipientUserId,
          'callType': callType.name,
          if (childId != null) 'childId': childId,
        },
      },
    );
    final data = result['data']?['initiateCall'] as Map<String, dynamic>?;
    if (data == null) throw Exception('Failed to initiate call');
    return CallSessionModel.fromJson(data);
  }

  Future<CallSessionModel> acceptCall(String callSessionId) async {
    final result = await _graphql.query(
      _acceptCall,
      variables: {'callSessionId': callSessionId},
    );
    final data = result['data']?['acceptCall'] as Map<String, dynamic>?;
    if (data == null) throw Exception('Failed to accept call');
    return CallSessionModel.fromJson(data);
  }

  Future<void> declineCall(
    String callSessionId, {
    String? reason,
  }) async {
    final result = await _graphql.query(
      _declineCall,
      variables: {
        'callSessionId': callSessionId,
        if (reason != null) 'reason': reason,
      },
    );
    if (result['data']?['declineCall'] == null) {
      throw Exception('Failed to decline call');
    }
  }

  Future<void> endCall(String callSessionId) async {
    final result = await _graphql.query(
      _endCall,
      variables: {'callSessionId': callSessionId},
    );
    if (result['data']?['endCall'] == null) {
      throw Exception('Failed to end call');
    }
  }

  Future<void> cancelCall(String callSessionId) async {
    final result = await _graphql.query(
      _cancelCall,
      variables: {'callSessionId': callSessionId},
    );
    if (result['data']?['cancelCall'] == null) {
      throw Exception('Failed to cancel call');
    }
  }

  Future<List<CallSessionModel>> fetchCallHistory({
    String? childId,
    String? userId,
    String? status,
    String? callType,
    int? limit,
  }) async {
    final result = await _graphql.query(
      _callHistory,
      variables: {
        'filter': {
          if (childId != null) 'childId': childId,
          if (userId != null) 'userId': userId,
          if (status != null) 'status': status,
          if (callType != null) 'callType': callType,
          if (limit != null) 'limit': limit,
        },
      },
    );
    final list = result['data']?['callHistory'] as List<dynamic>? ?? [];
    return list
        .map((e) => CallSessionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CallSessionModel?> fetchIncomingRingingCall() async {
    final result = await _graphql.query(_incomingRinging);
    final data = result['data']?['incomingRingingCall'];
    if (data == null) return null;
    return CallSessionModel.fromJson(data as Map<String, dynamic>);
  }

  Future<CallSessionModel?> fetchCallSession(String callSessionId) async {
    final result = await _graphql.query(
      _callSession,
      variables: {'callSessionId': callSessionId},
    );
    final data = result['data']?['callSession'];
    if (data == null) return null;
    return CallSessionModel.fromJson(data as Map<String, dynamic>);
  }

  Future<List<CallAuditLogModel>> fetchAgencyAuditLogs({
    String? childId,
    String? userId,
    String? role,
    String? status,
    String? callType,
    String? callSessionId,
    int? limit,
  }) async {
    final result = await _graphql.query(
      _agencyAudit,
      variables: {
        'filter': {
          if (childId != null) 'childId': childId,
          if (userId != null) 'userId': userId,
          if (role != null) 'role': role,
          if (status != null) 'status': status,
          if (callType != null) 'callType': callType,
          if (callSessionId != null) 'callSessionId': callSessionId,
          if (limit != null) 'limit': limit,
        },
      },
    );
    final list = result['data']?['agencyCallAuditLogs'] as List<dynamic>? ?? [];
    return list
        .map((e) => CallAuditLogModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
