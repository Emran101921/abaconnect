import '../../../core/network/graphql_client.dart';

class AgencyDashboardModel {
  const AgencyDashboardModel({
    required this.therapistCount,
    required this.activeClients,
    required this.appointmentsToday,
    required this.pendingTherapists,
    required this.missingEvvCount,
    required this.draftClaimsCount,
    required this.cancellationsToday,
    this.actionItems = const [],
  });

  final int therapistCount;
  final int activeClients;
  final int appointmentsToday;
  final int pendingTherapists;
  final int missingEvvCount;
  final int draftClaimsCount;
  final int cancellationsToday;
  final List<Map<String, dynamic>> actionItems;
}

class AgencyAppointmentModel {
  const AgencyAppointmentModel({
    required this.id,
    required this.scheduledStart,
    required this.scheduledEnd,
    required this.therapyType,
    required this.status,
    required this.locationType,
    required this.childName,
    required this.therapistName,
  });

  final String id;
  final DateTime scheduledStart;
  final DateTime scheduledEnd;
  final String therapyType;
  final String status;
  final String locationType;
  final String childName;
  final String therapistName;
}

class AgencyTherapistModel {
  const AgencyTherapistModel({
    required this.id,
    required this.displayName,
    required this.isVerified,
    this.licenseNumber,
  });

  final String id;
  final String displayName;
  final bool isVerified;
  final String? licenseNumber;
}

class AgencyClaimsPipelineSummaryModel {
  const AgencyClaimsPipelineSummaryModel({
    required this.draftCount,
    required this.submittedCount,
    required this.pendingCount,
    required this.paidCount,
    required this.deniedCount,
  });

  final int draftCount;
  final int submittedCount;
  final int pendingCount;
  final int paidCount;
  final int deniedCount;
}

class AgencyClaimSummaryModel {
  const AgencyClaimSummaryModel({
    required this.id,
    required this.status,
    required this.payerName,
    required this.billedAmount,
    required this.serviceDate,
    this.childName,
    this.claimNumber,
  });

  final String id;
  final String status;
  final String payerName;
  final double billedAmount;
  final DateTime serviceDate;
  final String? childName;
  final String? claimNumber;
}

class AgencyClaimsPipelineModel {
  const AgencyClaimsPipelineModel({
    required this.summary,
    required this.recentClaims,
  });

  final AgencyClaimsPipelineSummaryModel summary;
  final List<AgencyClaimSummaryModel> recentClaims;
}

class AgencyScreeningFunnelSummaryModel {
  const AgencyScreeningFunnelSummaryModel({
    required this.completedCount,
    required this.lowRiskCount,
    required this.moderateRiskCount,
    required this.highRiskCount,
  });

  final int completedCount;
  final int lowRiskCount;
  final int moderateRiskCount;
  final int highRiskCount;
}

class AgencyScreeningSummaryModel {
  const AgencyScreeningSummaryModel({
    required this.id,
    required this.completedAt,
    this.childName,
    this.templateName,
    this.score,
    this.riskLevel,
  });

  final String id;
  final DateTime completedAt;
  final String? childName;
  final String? templateName;
  final double? score;
  final String? riskLevel;
}

class AgencyClaimDetailModel {
  const AgencyClaimDetailModel({
    required this.id,
    required this.status,
    required this.payerName,
    required this.billedAmount,
    required this.serviceDate,
    this.approvedAmount,
    this.childName,
    this.parentEmail,
    this.denialReason,
    this.claimNumber,
    this.sessionId,
    this.ediReady,
    this.clearinghouseStatus,
  });

  final String id;
  final String status;
  final String payerName;
  final double billedAmount;
  final DateTime serviceDate;
  final double? approvedAmount;
  final String? childName;
  final String? parentEmail;
  final String? denialReason;
  final String? claimNumber;
  final String? sessionId;
  final bool? ediReady;
  final String? clearinghouseStatus;
}

class AgencyScreeningDetailModel {
  const AgencyScreeningDetailModel({
    required this.id,
    required this.completedAt,
    this.childName,
    this.templateName,
    this.score,
    this.riskLevel,
    this.responsesJson,
  });

  final String id;
  final DateTime completedAt;
  final String? childName;
  final String? templateName;
  final double? score;
  final String? riskLevel;
  final String? responsesJson;
}

class AgencyScreeningFunnelModel {
  const AgencyScreeningFunnelModel({
    required this.summary,
    required this.recentScreenings,
  });

  final AgencyScreeningFunnelSummaryModel summary;
  final List<AgencyScreeningSummaryModel> recentScreenings;
}

class AgencyRepository {
  AgencyRepository(this._graphql);

  final GraphqlClient _graphql;

  static const _dashboardQuery = r'''
    query AgencyDashboard {
      agencyDashboard {
        therapistCount
        activeClients
        appointmentsToday
        pendingTherapists
        missingEvvCount
        draftClaimsCount
        cancellationsToday
        actionItems {
          id title subtitle actionType priority
          threadId appointmentId sessionId claimId
        }
      }
    }
  ''';

  static const _therapistsQuery = r'''
    query AgencyTherapists {
      agencyTherapists {
        id
        isVerified
        licenseNumber
        user { firstName lastName }
      }
    }
  ''';

  Future<AgencyDashboardModel> fetchDashboard() async {
    final result = await _graphql.query(_dashboardQuery);
    final data = result['data']?['agencyDashboard'] as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Failed to load agency dashboard');
    }
    return AgencyDashboardModel(
      therapistCount: data['therapistCount'] as int? ?? 0,
      activeClients: data['activeClients'] as int? ?? 0,
      appointmentsToday: data['appointmentsToday'] as int? ?? 0,
      pendingTherapists: data['pendingTherapists'] as int? ?? 0,
      missingEvvCount: data['missingEvvCount'] as int? ?? 0,
      draftClaimsCount: data['draftClaimsCount'] as int? ?? 0,
      cancellationsToday: data['cancellationsToday'] as int? ?? 0,
      actionItems: (data['actionItems'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>(),
    );
  }

  static const _availableInviteQuery = r'''
    query AvailableInvite {
      agencyTherapistsAvailableToInvite {
        id
        isVerified
        licenseNumber
        user { firstName lastName }
      }
    }
  ''';

  static const _inviteMutation = r'''
    mutation Invite($therapistId: ID!) {
      inviteAgencyTherapist(therapistId: $therapistId) {
        id
        isVerified
      }
    }
  ''';

  Future<List<AgencyTherapistModel>> fetchAvailableToInvite() async {
    final result = await _graphql.query(_availableInviteQuery);
    final list = result['data']?['agencyTherapistsAvailableToInvite']
            as List<dynamic>? ??
        [];
    return list.map(_mapTherapist).toList();
  }

  Future<void> removeTherapist(String therapistId) async {
    await _graphql.query(
      r'''
      mutation Remove($therapistId: ID!) {
        removeAgencyTherapist(therapistId: $therapistId)
      }
    ''',
      variables: {'therapistId': therapistId},
    );
  }

  Future<void> inviteTherapist(String therapistId) async {
    await _graphql.query(
      _inviteMutation,
      variables: {'therapistId': therapistId},
    );
  }

  static const _upcomingAppointmentsQuery = r'''
    query AgencyUpcoming {
      agencyUpcomingAppointments {
        id
        scheduledStart
        scheduledEnd
        therapyType
        status
        locationType
        childName
        therapistName
      }
    }
  ''';

  Future<List<AgencyAppointmentModel>> fetchUpcomingAppointments() async {
    final result = await _graphql.query(_upcomingAppointmentsQuery);
    final list =
        result['data']?['agencyUpcomingAppointments'] as List<dynamic>? ?? [];
    return list.map((e) {
      return AgencyAppointmentModel(
        id: e['id'] as String,
        scheduledStart: DateTime.parse(e['scheduledStart'] as String),
        scheduledEnd: DateTime.parse(e['scheduledEnd'] as String),
        therapyType: e['therapyType'] as String? ?? '',
        status: e['status'] as String? ?? '',
        locationType: e['locationType'] as String? ?? '',
        childName: e['childName'] as String? ?? '',
        therapistName: e['therapistName'] as String? ?? '',
      );
    }).toList();
  }

  Future<List<AgencyTherapistModel>> fetchTherapists() async {
    final result = await _graphql.query(_therapistsQuery);
    final list = result['data']?['agencyTherapists'] as List<dynamic>? ?? [];
    return list.map(_mapTherapist).toList();
  }

  AgencyTherapistModel _mapTherapist(dynamic e) {
    final user = e['user'] as Map<String, dynamic>?;
    final name = user != null
        ? '${user['firstName']} ${user['lastName']}'
        : 'Therapist';
    return AgencyTherapistModel(
      id: e['id'] as String,
      displayName: name,
      isVerified: e['isVerified'] as bool? ?? false,
      licenseNumber: e['licenseNumber'] as String?,
    );
  }

  Future<List<Map<String, dynamic>>> fetchTenantAnalytics() async {
    const query = r'''
      query {
        tenantAnalytics { metricKey metricValue }
      }
    ''';
    final result = await _graphql.query(query);
    final list = result['data']?['tenantAnalytics'] as List<dynamic>? ?? [];
    return list
        .map(
          (e) => {
            'key': e['metricKey'] as String? ?? '',
            'value': (e['metricValue'] as num?)?.toDouble() ?? 0,
          },
        )
        .toList();
  }

  Future<AgencyClaimsPipelineModel> fetchClaimsPipeline() async {
    const query = r'''
      query {
        agencyClaimsPipeline {
          summary {
            draftCount submittedCount pendingCount paidCount deniedCount
          }
          recentClaims {
            id status payerName billedAmount serviceDate childName claimNumber
          }
        }
      }
    ''';
    final result = await _graphql.query(query);
    final data =
        result['data']?['agencyClaimsPipeline'] as Map<String, dynamic>? ?? {};
    return _mapClaimsPipeline(data);
  }

  Future<AgencyClaimDetailModel> fetchAnalyticsClaimDetail(String claimId) async {
    const query = r'''
      query ClaimDetail($claimId: ID!) {
        agencyAnalyticsClaimDetail(claimId: $claimId) {
          id status payerName billedAmount approvedAmount serviceDate
          childName parentEmail denialReason claimNumber sessionId
          ediReady clearinghouseStatus
        }
      }
    ''';
    final result = await _graphql.query(
      query,
      variables: {'claimId': claimId},
    );
    final e =
        result['data']?['agencyAnalyticsClaimDetail'] as Map<String, dynamic>?;
    if (e == null) throw Exception('Claim not found');
    return AgencyClaimDetailModel(
      id: e['id'] as String,
      status: e['status'] as String? ?? '',
      payerName: e['payerName'] as String? ?? '',
      billedAmount: (e['billedAmount'] as num?)?.toDouble() ?? 0,
      approvedAmount: (e['approvedAmount'] as num?)?.toDouble(),
      serviceDate: DateTime.parse(e['serviceDate'] as String),
      childName: e['childName'] as String?,
      parentEmail: e['parentEmail'] as String?,
      denialReason: e['denialReason'] as String?,
      claimNumber: e['claimNumber'] as String?,
      sessionId: e['sessionId'] as String?,
      ediReady: e['ediReady'] as bool?,
      clearinghouseStatus: e['clearinghouseStatus'] as String?,
    );
  }

  Future<AgencyScreeningDetailModel> fetchAnalyticsScreeningDetail(
    String screeningId,
  ) async {
    const query = r'''
      query ScreeningDetail($screeningId: ID!) {
        agencyAnalyticsScreeningDetail(screeningId: $screeningId) {
          id completedAt childName templateName score riskLevel responsesJson
        }
      }
    ''';
    final result = await _graphql.query(
      query,
      variables: {'screeningId': screeningId},
    );
    final e = result['data']?['agencyAnalyticsScreeningDetail']
        as Map<String, dynamic>?;
    if (e == null) throw Exception('Screening not found');
    return AgencyScreeningDetailModel(
      id: e['id'] as String,
      completedAt: DateTime.parse(e['completedAt'] as String),
      childName: e['childName'] as String?,
      templateName: e['templateName'] as String?,
      score: (e['score'] as num?)?.toDouble(),
      riskLevel: e['riskLevel'] as String?,
      responsesJson: e['responsesJson'] as String?,
    );
  }

  Future<AgencyScreeningFunnelModel> fetchScreeningFunnel() async {
    const query = r'''
      query {
        agencyScreeningFunnel {
          summary {
            completedCount lowRiskCount moderateRiskCount highRiskCount
          }
          recentScreenings {
            id completedAt childName templateName score riskLevel
          }
        }
      }
    ''';
    final result = await _graphql.query(query);
    final data =
        result['data']?['agencyScreeningFunnel'] as Map<String, dynamic>? ??
            {};
    return _mapScreeningFunnel(data);
  }

  AgencyClaimsPipelineModel _mapClaimsPipeline(Map<String, dynamic> data) {
    final summary = data['summary'] as Map<String, dynamic>? ?? {};
    final claims = data['recentClaims'] as List<dynamic>? ?? [];
    return AgencyClaimsPipelineModel(
      summary: AgencyClaimsPipelineSummaryModel(
        draftCount: summary['draftCount'] as int? ?? 0,
        submittedCount: summary['submittedCount'] as int? ?? 0,
        pendingCount: summary['pendingCount'] as int? ?? 0,
        paidCount: summary['paidCount'] as int? ?? 0,
        deniedCount: summary['deniedCount'] as int? ?? 0,
      ),
      recentClaims: claims
          .map(
            (e) => AgencyClaimSummaryModel(
              id: e['id'] as String,
              status: e['status'] as String? ?? '',
              payerName: e['payerName'] as String? ?? '',
              billedAmount: (e['billedAmount'] as num?)?.toDouble() ?? 0,
              serviceDate: DateTime.parse(e['serviceDate'] as String),
              childName: e['childName'] as String?,
              claimNumber: e['claimNumber'] as String?,
            ),
          )
          .toList(),
    );
  }

  AgencyScreeningFunnelModel _mapScreeningFunnel(Map<String, dynamic> data) {
    final summary = data['summary'] as Map<String, dynamic>? ?? {};
    final screenings = data['recentScreenings'] as List<dynamic>? ?? [];
    return AgencyScreeningFunnelModel(
      summary: AgencyScreeningFunnelSummaryModel(
        completedCount: summary['completedCount'] as int? ?? 0,
        lowRiskCount: summary['lowRiskCount'] as int? ?? 0,
        moderateRiskCount: summary['moderateRiskCount'] as int? ?? 0,
        highRiskCount: summary['highRiskCount'] as int? ?? 0,
      ),
      recentScreenings: screenings
          .map(
            (e) => AgencyScreeningSummaryModel(
              id: e['id'] as String,
              completedAt: DateTime.parse(e['completedAt'] as String),
              childName: e['childName'] as String?,
              templateName: e['templateName'] as String?,
              score: (e['score'] as num?)?.toDouble(),
              riskLevel: e['riskLevel'] as String?,
            ),
          )
          .toList(),
    );
  }
}
