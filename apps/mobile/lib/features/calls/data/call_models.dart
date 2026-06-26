enum CallType { AUDIO, VIDEO }

enum CallSessionStatus {
  INITIATED,
  RINGING,
  ACCEPTED,
  IN_PROGRESS,
  DECLINED,
  MISSED,
  FAILED,
  ENDED,
  CANCELLED,
}

class CallParticipantModel {
  CallParticipantModel({
    required this.userId,
    required this.displayName,
    required this.role,
    required this.joinStatus,
  });

  final String userId;
  final String displayName;
  final String role;
  final String joinStatus;

  factory CallParticipantModel.fromJson(Map<String, dynamic> json) {
    return CallParticipantModel(
      userId: json['userId'] as String,
      displayName: json['displayName'] as String,
      role: json['role'] as String,
      joinStatus: json['joinStatus'] as String,
    );
  }
}

class CallSessionModel {
  CallSessionModel({
    required this.id,
    required this.callType,
    required this.status,
    required this.initiatedByUserId,
    required this.initiatedByName,
    required this.createdAt,
    this.childId,
    this.recipientUserId,
    this.recipientName,
    this.startedAt,
    this.endedAt,
    this.durationSeconds,
    this.joinUrl,
    this.token,
    this.tokenExpiresAt,
    this.providerName = 'stub',
    this.participants = const [],
    this.jobInterviewId,
  });

  final String id;
  final CallType callType;
  final CallSessionStatus status;
  final String? childId;
  final String initiatedByUserId;
  final String initiatedByName;
  final String? recipientUserId;
  final String? recipientName;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int? durationSeconds;
  final DateTime createdAt;
  final String? joinUrl;
  final String? token;
  final DateTime? tokenExpiresAt;
  final String providerName;
  final List<CallParticipantModel> participants;
  final String? jobInterviewId;

  bool get isMissed => status == CallSessionStatus.MISSED;
  bool get isEnded => status == CallSessionStatus.ENDED;

  factory CallSessionModel.fromJson(Map<String, dynamic> json) {
    return CallSessionModel(
      id: json['id'] as String,
      callType: CallType.values.byName(json['callType'] as String),
      status: CallSessionStatus.values.byName(json['status'] as String),
      childId: json['childId'] as String?,
      initiatedByUserId: json['initiatedByUserId'] as String,
      initiatedByName: json['initiatedByName'] as String,
      recipientUserId: json['recipientUserId'] as String?,
      recipientName: json['recipientName'] as String?,
      startedAt: json['startedAt'] != null
          ? DateTime.parse(json['startedAt'] as String)
          : null,
      endedAt: json['endedAt'] != null
          ? DateTime.parse(json['endedAt'] as String)
          : null,
      durationSeconds: json['durationSeconds'] as int?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      joinUrl: json['joinUrl'] as String?,
      token: json['token'] as String?,
      tokenExpiresAt: json['tokenExpiresAt'] != null
          ? DateTime.parse(json['tokenExpiresAt'] as String)
          : null,
      providerName: json['providerName'] as String? ?? 'stub',
      participants: (json['participants'] as List<dynamic>?)
              ?.map(
                (e) => CallParticipantModel.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
    );
  }
}

class CallAuditLogModel {
  CallAuditLogModel({
    required this.id,
    required this.callSessionId,
    required this.actorUserId,
    required this.actorRole,
    required this.eventType,
    required this.createdAt,
    this.childId,
    this.targetUserId,
    this.targetRole,
    this.callType,
    this.callStatus,
    this.reason,
  });

  final String id;
  final String callSessionId;
  final String? childId;
  final String actorUserId;
  final String actorRole;
  final String? targetUserId;
  final String? targetRole;
  final String eventType;
  final CallType? callType;
  final CallSessionStatus? callStatus;
  final String? reason;
  final DateTime createdAt;

  factory CallAuditLogModel.fromJson(Map<String, dynamic> json) {
    return CallAuditLogModel(
      id: json['id'] as String,
      callSessionId: json['callSessionId'] as String,
      childId: json['childId'] as String?,
      actorUserId: json['actorUserId'] as String,
      actorRole: json['actorRole'] as String,
      targetUserId: json['targetUserId'] as String?,
      targetRole: json['targetRole'] as String?,
      eventType: json['eventType'] as String,
      callType: json['callType'] != null
          ? CallType.values.byName(json['callType'] as String)
          : null,
      callStatus: json['callStatus'] != null
          ? CallSessionStatus.values.byName(json['callStatus'] as String)
          : null,
      reason: json['reason'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
